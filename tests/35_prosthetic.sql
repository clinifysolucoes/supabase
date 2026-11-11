-- ============================================================================
-- Controle Protetico (ad.prosthetic_list / _save / _stage): trabalhos enviados
-- ao laboratorio, etapas, atraso e conta a pagar no recebimento.
--   Rui = administrador da empresa
--   Leo = protetico (PROSTHETIC ler/criar/alterar; sem Financeiro)
--   Mia = so le PROSTHETIC
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/35_prosthetic.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', 'rui.prot@test.local', '{"name": "Rui Prot"}'),
  ('00000000-0000-0000-0000-0000000000e2', 'leo.prot@test.local', '{"name": "Leo Prot"}'),
  ('00000000-0000-0000-0000-0000000000e3', 'mia.prot@test.local', '{"name": "Mia Prot"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Rui: cadastro, etapas, atraso e conta a pagar'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _pb    bigint;
  _prof  bigint;
  _sup   bigint;
  _nb    bigint;
  _w1    bigint;
  _w2    bigint;
  _today date := (now() at time zone 'America/Sao_Paulo')::date;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Prot"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Ana Prot', 'dt_birth', '1980-05-10',
           'vc_cpf', '529.982.247-25')) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Beto Prot', 'dt_birth', '1975-02-02',
           'vc_cpf', '111.444.777-35')) ->> 'nr_patient')::bigint;
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dr. Caio"}'::jsonb) ->> 'nr_professional')::bigint;
  perform ad.fin_setup(_base);
  _sup := (ad.fin_supplier_save(_base || '{"vc_action": "I", "vc_name": "Lab Sorriso"}'::jsonb) ->> 'nr_supplier')::bigint;
  perform set_config('test.nr_pa', _pa::text, false);
  perform set_config('test.nr_sup', _sup::text, false);
  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pb, 'dt_budget', current_date,
          'items', '[{"vc_description": "Coroa", "vl_unit": 900}]'::jsonb))) -> 'budget' ->> 'nr_budget')::bigint;

  -- consistencias
  perform pg_temp.expect_error('prosthetic_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa),
            'PROSTHETIC_DESCRIPTION_REQUIRED');
  perform pg_temp.expect_error('prosthetic_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'vc_description', 'Coroa', 'nr_supplier', 999), 'PROSTHETIC_LAB_INVALID');
  perform pg_temp.expect_error('prosthetic_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'vc_description', 'Coroa', 'nr_budget', _nb, 'nr_item', 1), 'PROSTHETIC_ITEM_INVALID');
  perform pg_temp.expect_error('prosthetic_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', 999,
            'vc_description', 'Coroa'), 'PATIENT_NOT_FOUND');
  perform pg_temp.expect_error('prosthetic_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'vc_description', 'Coroa', 'vl_cost', -1), 'PROSTHETIC_VALUE_INVALID');

  -- trabalho com laboratorio cadastrado e custo
  _w1 := (ad.prosthetic_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _prof,
            'nr_supplier', _sup, 'vc_description', 'Coroa metalocerâmica', 'vc_tooth', '16', 'vc_shade', 'A2',
            'vl_cost', 300)) ->> 'nr_work')::bigint;
  -- outro paciente, ligado ao item do orcamento, laboratorio sem cadastro
  _w2 := (ad.prosthetic_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pb, 'nr_budget', _nb, 'nr_item', 1,
            'vc_lab', 'Lab do Zé', 'vc_description', 'Coroa', 'vl_cost', 100)) ->> 'nr_work')::bigint;
  assert _w1 = 1 and _w2 = 2, 'numeracao';

  -- envio com previsao vencida: atrasado
  perform pg_temp.expect_error('prosthetic_stage', _base || jsonb_build_object('nr_work', _w1, 'it_stage', 1),
            'PROSTHETIC_STAGE_INVALID');
  perform pg_temp.expect_error('prosthetic_stage', _base || jsonb_build_object('nr_work', _w1, 'it_stage', 7),
            'PROSTHETIC_STAGE_INVALID');
  perform pg_temp.expect_error('prosthetic_stage', _base || jsonb_build_object('nr_work', _w1, 'it_stage', 2,
            'dt_step', _today + 1), 'PROSTHETIC_VALUE_INVALID');
  perform ad.prosthetic_stage(_base || jsonb_build_object('nr_work', _w1, 'it_stage', 2, 'dt_step', _today - 10,
            'dt_expected', _today - 1, 'vc_notes', 'Moldagem enviada'));
  _r := ad.prosthetic_list(_base || '{"vc_filter": "late"}'::jsonb);
  assert jsonb_array_length(_r -> 'works') = 1 and (_r -> 'works' -> 0 ->> 'id_late')::boolean
     and _r -> 'works' -> 0 ->> 'vc_lab' = 'Lab Sorriso', 'atrasado: ' || (_r -> 'works')::text;
  assert (_r -> 'totals' ->> 'qt_at_lab')::int = 1 and (_r -> 'totals' ->> 'qt_to_send')::int = 1
     and (_r -> 'totals' ->> 'qt_late')::int = 1, 'totais: ' || (_r -> 'totals')::text;
  assert jsonb_array_length(_r -> 'labs') = 1, 'laboratorios';

  -- prova na clinica e reenvio: deixa de estar atrasado
  perform ad.prosthetic_stage(_base || jsonb_build_object('nr_work', _w1, 'it_stage', 3, 'vc_notes', 'Ajustar cor'));
  perform ad.prosthetic_stage(_base || jsonb_build_object('nr_work', _w1, 'it_stage', 2, 'dt_expected', _today + 5));
  assert (ad.prosthetic_list(_base || '{"vc_filter": "late"}'::jsonb) -> 'totals' ->> 'qt_late')::int = 0, 'sem atraso';

  -- recebido: gera a conta a pagar do laboratorio
  _r := ad.prosthetic_stage(_base || jsonb_build_object('nr_work', _w1, 'it_stage', 4, 'dt_due', _today + 20));
  assert (_r ->> 'nr_entry') is not null and not (_r ->> 'id_fin_skipped')::boolean, 'conta gerada: ' || _r::text;
  perform set_config('test.nr_entry', _r ->> 'nr_entry', false);
  perform pg_temp.expect_error('prosthetic_save', _base || jsonb_build_object('vc_action', 'U', 'nr_work', _w1,
            'vl_cost', 400), 'PROSTHETIC_ENTRY_EXISTS');
  perform ad.prosthetic_save(_base || jsonb_build_object('vc_action', 'U', 'nr_work', _w1, 'vc_notes', 'Ficou ótima'));

  -- instalado: fecha o trabalho
  perform ad.prosthetic_stage(_base || jsonb_build_object('nr_work', _w1, 'it_stage', 5));
  perform pg_temp.expect_error('prosthetic_stage', _base || jsonb_build_object('nr_work', _w1, 'it_stage', 90),
            'PROSTHETIC_CLOSED');
  _r := ad.prosthetic_list(_base || jsonb_build_object('nr_work', _w1));
  assert jsonb_array_length(_r -> 'works' -> 0 -> 'steps') = 6 and (_r -> 'works' -> 0 ->> 'it_stage')::int = 5
     and _r -> 'works' -> 0 ->> 'dt_installed' is not null and _r -> 'works' -> 0 ->> 'vc_notes' = 'Ficou ótima'
     and (_r -> 'works' -> 0 ->> 'it_entry_status')::int = 1, 'historico: ' || (_r -> 'works' -> 0)::text;
  assert jsonb_array_length(ad.prosthetic_list(_base || '{"vc_filter": "done"}'::jsonb) -> 'works') = 1, 'instalados';

  -- sem laboratorio cadastrado nao gera conta
  _r := ad.prosthetic_stage(_base || jsonb_build_object('nr_work', _w2, 'it_stage', 4));
  assert (_r ->> 'nr_entry') is null and not (_r ->> 'id_fin_skipped')::boolean, 'sem fornecedor sem conta';
  assert jsonb_array_length(ad.prosthetic_list(_base || '{"vc_search": "zé"}'::jsonb) -> 'works') = 1, 'busca pelo lab';

  -- Leo (protetico, sem Financeiro) e Mia (so le)
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Prótese', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000012',
                                                          'id_read', true, 'id_create', true, 'id_update', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'leo.prot@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Consulta prótese', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000012', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'mia.prot@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

-- a conta a pagar gerada
reset role;
do $$
begin
  assert (select e.it_kind = 2 and e.vl_amount = 300 and e.nr_supplier = current_setting('test.nr_sup')::bigint
                 and e.dt_due = (now() at time zone 'America/Sao_Paulo')::date + 20
                 and e.vc_description like 'Laboratório: Coroa metalocerâmica (Ana Prot)'
            from od.fin_entry e
           where e.nr_company = current_setting('test.nr_company')::bigint
             and e.nr_entry = current_setting('test.nr_entry')::bigint), 'conta a pagar do laboratorio';
end $$;

\echo '== Leo: recebe sem Financeiro (conta nao gerada)'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _w    bigint;
  _r    jsonb;
begin
  _w := (ad.prosthetic_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', current_setting('test.nr_pa')::bigint,
          'nr_supplier', current_setting('test.nr_sup')::bigint, 'vc_description', 'Placa', 'vl_cost', 50)) ->> 'nr_work')::bigint;
  _r := ad.prosthetic_stage(_base || jsonb_build_object('nr_work', _w, 'it_stage', 4));
  assert (_r ->> 'id_fin_skipped')::boolean and (_r ->> 'nr_entry') is null, 'sem Financeiro: ' || _r::text;
end $$;

\echo '== Mia: so le'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e3","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  assert jsonb_array_length(ad.prosthetic_list(_base || '{"vc_filter": "all"}'::jsonb) -> 'works') = 3, 'le todos';
  perform pg_temp.expect_error('prosthetic_save', _base || jsonb_build_object('vc_action', 'I',
            'nr_patient', current_setting('test.nr_pa')::bigint, 'vc_description', 'X'), 'PROSTHETIC_FORBIDDEN');
  perform pg_temp.expect_error('prosthetic_stage', _base || '{"nr_work": 2, "it_stage": 5}'::jsonb, 'PROSTHETIC_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.prosthetic_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou prosthetic_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 35_prosthetic'
