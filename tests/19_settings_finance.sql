-- ============================================================================
-- Configuracoes, parte B: bloqueio de paciente com conta vencida na agenda
-- (ad.appointment_save), caixa desligado (ad.fin_cash_open/status), formas
-- de pagamento aceitas (ad.fin_entry_settle) e multa/juros por atraso
-- (od.fn_fin_late_charge em fin_entry_list e fin_entry_settle).
--   Mel = administradora da empresa
--   Ivo = recepcao (agenda ler + criar)
-- Vencimentos relativos a hoje; consultas em 2030; termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/19_settings_finance.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f5', 'mel.cfgb@test.local', '{"name": "Mel ConfigB"}'),
  ('00000000-0000-0000-0000-0000000000f6', 'ivo.cfgb@test.local', '{"name": "Ivo ConfigB"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f5","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Mel: regras do financeiro e da agenda'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _cat   jsonb;
  _cx    bigint;
  _rec   bigint;
  _pa    bigint;
  _pb    bigint;
  _ana   bigint;
  _e1    bigint;
  _ap    jsonb;
  _x     jsonb;
  _prof  bigint;
  _today date;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica ConfigB"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  select (now() at time zone b.vc_timezone)::date into _today from ad.branch b where b.nr_company = _ca and b.nr_branch = 1;

  -- padroes
  _r := ad.settings_get(_base) -> 'settings';
  assert (_r ->> 'it_debt_rule')::int = 1 and (_r ->> 'qt_debt_days')::int = 0 and (_r ->> 'id_cash_enabled')::boolean
     and jsonb_array_length(_r -> 'it_payment_methods') = 8 and (_r ->> 'pc_late_fee')::numeric = 0, 'padroes parte B';

  -- validacoes
  perform pg_temp.expect_error('settings_save', _base || '{"it_debt_rule": 5}'::jsonb, 'SETTINGS_DEBT_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"qt_debt_days": 400}'::jsonb, 'SETTINGS_DEBT_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"it_payment_methods": []}'::jsonb, 'SETTINGS_METHODS_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"it_payment_methods": [1, 8]}'::jsonb, 'SETTINGS_METHODS_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"it_payment_methods": "1"}'::jsonb, 'SETTINGS_METHODS_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"pc_late_fee": 11}'::jsonb, 'SETTINGS_LATE_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"pc_late_interest": -1}'::jsonb, 'SETTINGS_LATE_INVALID');

  -- cadastros
  perform ad.fin_setup(_base);
  _cat := ad.fin_catalog(_base);
  _cx  := (select (x ->> 'nr_account')::bigint from jsonb_array_elements(_cat -> 'accounts') x where x ->> 'vc_name' = 'Caixa');
  _rec := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x where x ->> 'vc_name' = 'Tratamentos');
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Paciente Devedor", "dt_birth": "1990-01-01"}'::jsonb) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Paciente Em Dia", "dt_birth": "1990-01-01"}'::jsonb) ->> 'nr_patient')::bigint;
  _ana := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Ana"}'::jsonb) ->> 'nr_professional')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  perform set_config('test.nr_professional', _ana::text, false);

  -- conta a receber vencida ha 40 dias
  _e1 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec, 'nr_patient', _pa,
           'vc_description', 'Tratamento', 'vl_amount', 1000, 'dt_due', _today - 40)) ->> 'nr_entry')::bigint;

  -- multa e juros: sem configuracao, zero
  _x := (select e from jsonb_array_elements(ad.fin_entry_list(_base || jsonb_build_object('it_kind', 1,
          'dt_from', _today - 60, 'dt_to', _today)) -> 'entries') e where (e ->> 'nr_entry')::bigint = _e1);
  assert (_x ->> 'vl_late_fee')::numeric = 0 and (_x ->> 'vl_late_interest')::numeric = 0, 'sem multa configurada';
  perform ad.settings_save(_base || '{"pc_late_fee": 2, "pc_late_interest": 1.5}'::jsonb);
  _x := (select e from jsonb_array_elements(ad.fin_entry_list(_base || jsonb_build_object('it_kind', 1,
          'dt_from', _today - 60, 'dt_to', _today)) -> 'entries') e where (e ->> 'nr_entry')::bigint = _e1);
  -- multa 2% de 1000 = 20; juros 1,5% ao mes pro rata: 1000 x 1,5 / 100 / 30 x 40 = 20
  assert (_x ->> 'vl_late_fee')::numeric = 20 and (_x ->> 'vl_late_interest')::numeric = 20,
    'multa e juros ate hoje, veio ' || _x::text;

  -- agenda: regra 1 (padrao) nao bloqueia
  _ap := _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _ana);
  _r := ad.appointment_save(_ap || '{"dh_start": "2030-03-04T09:00:00-03:00", "dh_end": "2030-03-04T09:30:00-03:00"}'::jsonb);
  assert _r -> 'debt' = 'null'::jsonb, 'regra 1: sem aviso';
  -- regra 2: agenda e avisa
  perform ad.settings_save(_base || '{"it_debt_rule": 2}'::jsonb);
  _r := ad.appointment_save(_ap || '{"dh_start": "2030-03-04T10:00:00-03:00", "dh_end": "2030-03-04T10:30:00-03:00"}'::jsonb);
  assert (_r -> 'debt' ->> 'qt_entries')::int = 1 and (_r -> 'debt' ->> 'vl_total')::numeric = 1000, 'regra 2: avisa';
  -- paciente em dia nao recebe aviso
  _r := ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pb, 'nr_professional', _ana,
          'dh_start', '2030-03-04T11:00:00-03:00', 'dh_end', '2030-03-04T11:30:00-03:00'));
  assert _r -> 'debt' = 'null'::jsonb, 'paciente em dia';
  -- regra 4: bloqueia, encaixe nao libera
  perform ad.settings_save(_base || '{"it_debt_rule": 4}'::jsonb);
  perform pg_temp.expect_error('appointment_save', _ap || '{"dh_start": "2030-03-04T12:00:00-03:00", "dh_end": "2030-03-04T12:30:00-03:00",
            "id_fit_in": true}'::jsonb, 'APPOINTMENT_DEBT_BLOCKED');
  -- tolerancia maior que o atraso: passa
  perform ad.settings_save(_base || '{"qt_debt_days": 60}'::jsonb);
  perform ad.appointment_save(_ap || '{"dh_start": "2030-03-04T12:00:00-03:00", "dh_end": "2030-03-04T12:30:00-03:00"}'::jsonb);
  -- regra 3: administrador confirma
  perform ad.settings_save(_base || '{"it_debt_rule": 3, "qt_debt_days": 0}'::jsonb);
  perform pg_temp.expect_error('appointment_save', _ap || '{"dh_start": "2030-03-04T13:00:00-03:00", "dh_end": "2030-03-04T13:30:00-03:00"}'::jsonb,
            'APPOINTMENT_DEBT_CONFIRM');
  _r := ad.appointment_save(_ap || '{"dh_start": "2030-03-04T13:00:00-03:00", "dh_end": "2030-03-04T13:30:00-03:00",
          "id_debt_override": true}'::jsonb);
  assert (_r -> 'debt' ->> 'qt_entries')::int = 1, 'regra 3: admin liberou';
  assert exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'appointment'
                    and (e.js_detail ->> 'debt_override')::boolean), 'liberacao no log';

  -- formas aceitas: so dinheiro e Pix
  perform ad.settings_save(_base || '{"it_payment_methods": [2, 1, 2]}'::jsonb);
  assert (ad.settings_get(_base) -> 'settings' -> 'it_payment_methods') = '[1, 2]'::jsonb, 'formas sem repeticao e em ordem';
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e1,
            'nr_account', _cx, 'it_payment_method', 3), 'FIN_ENTRY_METHOD_NOT_ACCEPTED');
  -- conta a pagar nao segue a lista
  _r := ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 2,
          'nr_category', (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x
                           where (x ->> 'it_kind')::int = 2 limit 1),
          'vc_description', 'Fornecedor', 'vl_amount', 50, 'dt_due', _today));
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', (_r ->> 'nr_entry')::bigint,
            'nr_account', _cx, 'it_payment_method', 6));

  -- baixa com atraso: valor padrao = valor + multa + juros
  _r := ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY', 'nr_entry', _e1, 'nr_account', _cx,
          'it_payment_method', 1));
  assert (_r -> 'late' ->> 'vl_total')::numeric = 40, 'multa e juros na baixa';
  assert (select vl_paid from od.fin_entry where nr_company = _ca and nr_entry = _e1) = 1040, 'pago com acrescimos';

  -- caixa desligado
  perform ad.settings_save(_base || '{"id_cash_enabled": false}'::jsonb);
  perform pg_temp.expect_error('fin_cash_open', _base || jsonb_build_object('nr_account', _cx), 'FIN_CASH_DISABLED');
  assert not (ad.fin_cash_status(_base) ->> 'id_enabled')::boolean, 'status: caixa desligado';
  perform ad.settings_save(_base || '{"id_cash_enabled": true}'::jsonb);
  perform ad.fin_cash_open(_base || jsonb_build_object('nr_account', _cx));

  -- nova conta vencida para a regra 3 com o Ivo
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _rec, 'nr_patient', _pa,
           'vc_description', 'Retorno', 'vl_amount', 200, 'dt_due', _today - 5));

  -- Ivo: recepcao (agenda ler + criar)
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000007',
                                                          'id_read', true, 'id_create', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ivo.cfgb@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));
end $$;

\echo '== Ivo (recepcao): regra 3 pede o administrador'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f6","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ap jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1,
                 'vc_action', 'I', 'nr_patient', current_setting('test.nr_patient')::bigint,
                 'nr_professional', current_setting('test.nr_professional')::bigint);
begin
  perform pg_temp.expect_error('appointment_save', _ap || '{"dh_start": "2030-03-05T09:00:00-03:00", "dh_end": "2030-03-05T09:30:00-03:00",
            "id_debt_override": true}'::jsonb, 'APPOINTMENT_DEBT_APPROVAL');
  -- compromisso (sem paciente) segue normal
  perform ad.appointment_save(_ap - 'nr_patient' || '{"it_type": 2, "vc_title": "Reunião",
            "dh_start": "2030-03-05T10:00:00-03:00", "dh_end": "2030-03-05T10:30:00-03:00"}'::jsonb);
end $$;

reset role;
rollback;
\o
\echo 'OK: 19_settings_finance'
