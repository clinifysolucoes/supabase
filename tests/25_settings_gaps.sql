-- ============================================================================
-- Configuracoes, lacunas: orcamento (preco minimo, reducao como desconto,
-- pedido de aprovacao), bloqueio de conta em aberto na agenda, edicao de multa
-- e juros, lixeira de profissionais e grupo da categoria no DRE.
--   Mel = administradora da empresa
--   Ivo = recepcao (orcamentos e financeiro: tudo; agenda: tudo)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/25_settings_gaps.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b7', 'mel.gap@test.local', '{"name": "Mel Gap"}'),
  ('00000000-0000-0000-0000-0000000000b8', 'ivo.gap@test.local', '{"name": "Ivo Gap"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b7","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Mel: cadastros'
do $$
declare
  _r    jsonb;
  _ca   bigint;
  _base jsonb;
  _pa   bigint;
  _sp   bigint;
  _imp  bigint;
  _ana  bigint;
  _cat  jsonb;
  _rec  bigint;
  _cx   bigint;
  _prof bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Gap"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Gap", "dt_birth": "1990-01-01",
           "vc_cpf": "529.982.247-25"}'::jsonb) ->> 'nr_patient')::bigint;
  _sp := (ad.specialty_save(_base || '{"vc_action": "I", "vc_name": "Prótese"}'::jsonb) ->> 'nr_specialty')::bigint;
  -- laboratorio 500: preco minimo bem acima de 300
  _imp := (ad.procedure_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Coroa', 'nr_specialty', _sp,
            'qt_minutes', 60, 'vl_lab_cost', 500, 'vl_current_price', 1500)) ->> 'nr_procedure')::bigint;
  _ana := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Ana"}'::jsonb) ->> 'nr_professional')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  perform set_config('test.nr_procedure', _imp::text, false);
  perform set_config('test.nr_professional', _ana::text, false);

  perform ad.fin_setup(_base);
  _cat := ad.fin_catalog(_base);
  _rec := (select (x ->> 'nr_category')::bigint from jsonb_array_elements(_cat -> 'categories') x where x ->> 'vc_name' = 'Tratamentos');
  _cx  := (select (x ->> 'nr_account')::bigint from jsonb_array_elements(_cat -> 'accounts') x where x ->> 'vc_name' = 'Caixa');
  perform set_config('test.nr_category', _rec::text, false);
  perform set_config('test.nr_account', _cx::text, false);

  -- Ivo: recepcao com agenda, orcamentos e financeiro
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000007', 'id_read', true, 'id_create', true, 'id_update', true),
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000008', 'id_read', true, 'id_create', true, 'id_update', true),
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000010', 'id_read', true, 'id_create', true, 'id_update', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ivo.gap@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));

  -- configuracoes novas: padroes e validacoes
  _r := ad.settings_get(_base) -> 'settings';
  assert (_r ->> 'id_budget_request_approval')::boolean and (_r ->> 'id_budget_admin_below_min')::boolean
     and not (_r ->> 'id_budget_reduction_as_discount')::boolean and (_r ->> 'it_open_rule')::int = 1
     and (_r ->> 'it_late_edit')::int = 0, 'padroes';
  perform pg_temp.expect_error('settings_save', _base || '{"it_open_rule": 9}'::jsonb, 'SETTINGS_DEBT_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"it_late_edit": 5}'::jsonb, 'SETTINGS_LATE_INVALID');
end $$;

\echo '== Ivo: orcamento abaixo do minimo e reducao como desconto'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _item jsonb := jsonb_build_array(jsonb_build_object('nr_procedure', current_setting('test.nr_procedure')::bigint, 'vl_unit', 300));
  _r    jsonb;
begin
  -- 300 < preco minimo: aguarda o administrador
  _r := ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', current_setting('test.nr_patient')::bigint,
          'items', _item));
  assert (_r -> 'budget' ->> 'it_status')::int = 2 and (_r -> 'budget' ->> 'id_below_min')::boolean, 'abaixo do minimo aguarda';
  perform set_config('test.nr_budget', _r -> 'budget' ->> 'nr_budget', false);
  -- 1400 (acima do minimo, 6,7% abaixo do cobrado): sem reducao como desconto fica em aberto
  _r := ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', current_setting('test.nr_patient')::bigint,
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', current_setting('test.nr_procedure')::bigint, 'vl_unit', 1300))));
  assert (_r -> 'budget' ->> 'it_status')::int = 1 and not (_r -> 'budget' ->> 'id_below_min')::boolean, 'reducao nao conta';
  perform set_config('test.nr_budget2', _r -> 'budget' ->> 'nr_budget', false);
end $$;

\echo '== Mel: liga reducao como desconto e tira o pedido de aprovacao'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b7","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  -- o administrador aprova o abaixo do minimo
  _r := ad.budget_status(_base || jsonb_build_object('nr_budget', current_setting('test.nr_budget')::bigint, 'vc_action', 'APPROVE_DISCOUNT'));
  assert (_r -> 'budget' ->> 'it_status')::int = 1, 'admin aprovou abaixo do minimo';
  perform ad.settings_save(_base || '{"id_budget_reduction_as_discount": true, "id_budget_request_approval": false,
           "it_open_rule": 4, "it_late_edit": 1, "pc_late_fee": 2, "pc_late_interest": 1}'::jsonb);
end $$;

\echo '== Ivo: reducao de 13% passa do maximo (10%) e e barrada; conta em aberto bloqueia a agenda; multa'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca   bigint := current_setting('test.nr_company')::bigint;
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _e1   bigint;
  _today date;
begin
  perform pg_temp.expect_error('budget_save', _base || jsonb_build_object('vc_action', 'U',
            'nr_budget', current_setting('test.nr_budget2')::bigint, 'vc_title', 'x'), 'BUDGET_DISCOUNT_OVER_MAX');

  -- conta em aberto (nao vencida) com regra 4: bloqueia
  select (now() at time zone b.vc_timezone)::date into _today from ad.branch b where b.nr_company = _ca and b.nr_branch = 1;
  _e1 := (ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1,
           'nr_category', current_setting('test.nr_category')::bigint, 'nr_patient', current_setting('test.nr_patient')::bigint,
           'vc_description', 'Parcela', 'vl_amount', 100, 'dt_due', _today + 10)) ->> 'nr_entry')::bigint;
  perform pg_temp.expect_error('appointment_save', _base || jsonb_build_object('vc_action', 'I',
            'nr_patient', current_setting('test.nr_patient')::bigint, 'nr_professional', current_setting('test.nr_professional')::bigint,
            'dh_start', '2030-03-04T09:00:00-03:00', 'dh_end', '2030-03-04T09:30:00-03:00'), 'APPOINTMENT_OPEN_BLOCKED');

  -- multa e juros: recepcao nao reduz (it_late_edit 1)
  perform set_config('test.nr_entry', _e1::text, false);
end $$;

\echo '== Mel: conta vencida para a multa'
reset role;
update od.fin_entry set dt_due = (now() at time zone 'America/Sao_Paulo')::date - 30
 where nr_company = current_setting('test.nr_company')::bigint and nr_entry = current_setting('test.nr_entry')::bigint;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('vc_action', 'PAY',
            'nr_entry', current_setting('test.nr_entry')::bigint, 'nr_account', current_setting('test.nr_account')::bigint,
            'vl_paid', 100), 'FIN_LATE_EDIT_ADMIN');
end $$;

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b7","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca   bigint := current_setting('test.nr_company')::bigint;
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
  _cat  bigint;
begin
  -- administrador pode reduzir; com it_late_edit 2 ninguem
  perform ad.settings_save(_base || '{"it_late_edit": 2}'::jsonb);
  perform pg_temp.expect_error('fin_entry_settle', _base || jsonb_build_object('vc_action', 'PAY',
            'nr_entry', current_setting('test.nr_entry')::bigint, 'nr_account', current_setting('test.nr_account')::bigint,
            'vl_paid', 100), 'FIN_LATE_EDIT_FORBIDDEN');
  perform ad.settings_save(_base || '{"it_late_edit": 1}'::jsonb);
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY',
            'nr_entry', current_setting('test.nr_entry')::bigint, 'nr_account', current_setting('test.nr_account')::bigint,
            'vl_paid', 100));

  -- lixeira: profissional inativado volta
  perform ad.professional_save(_base || jsonb_build_object('vc_action', 'U',
            'nr_professional', current_setting('test.nr_professional')::bigint, 'it_status', 90));
  _r := ad.trash_list(_base || '{"vc_kind": "professional"}'::jsonb);
  assert jsonb_array_length(_r -> 'items') = 1 and _r -> 'items' -> 0 ->> 'vc_title' = 'Dra. Ana', 'profissional na lixeira';
  perform ad.trash_restore(_base || jsonb_build_object('vc_kind', 'professional',
            'nr_key', current_setting('test.nr_professional')::bigint));
  assert (select it_status from od.professional where nr_company = _ca
            and nr_professional = current_setting('test.nr_professional')::bigint) = 1, 'profissional restaurado';

  -- DRE: categoria de receita como "receita nao operacional"
  perform pg_temp.expect_error('fin_category_save', _base || jsonb_build_object('vc_action', 'U',
            'nr_category', current_setting('test.nr_category')::bigint, 'it_dre_group', 9), 'FIN_CATEGORY_DRE_GROUP_INVALID');
  _cat := (ad.fin_category_save(_base || '{"vc_action": "I", "vc_name": "Rendimentos", "it_kind": 1, "it_dre_group": 6}'::jsonb)
           ->> 'nr_category')::bigint;
  perform ad.fin_entry_save(_base || jsonb_build_object('vc_action', 'I', 'it_kind', 1, 'nr_category', _cat,
            'vc_description', 'Aplicação', 'vl_amount', 50, 'dt_due', '2030-05-10'));
  _r := ad.fin_dre(_base || '{"dt_from": "2030-05-01", "dt_to": "2030-05-31"}'::jsonb);
  assert (select (l ->> 'vl_total')::numeric from jsonb_array_elements(_r -> 'lines') l where l ->> 'vc_key' = 'non_op_revenue') = 50
     and (select (l ->> 'vl_total')::numeric from jsonb_array_elements(_r -> 'lines') l where l ->> 'vc_key' = 'gross') = 0
     and (select (l ->> 'vl_total')::numeric from jsonb_array_elements(_r -> 'lines') l where l ->> 'vc_key' = 'result') = 50,
    'receita nao operacional fora da receita bruta, veio ' || (_r -> 'lines')::text;
  assert (select x ->> 'it_dre_group' from jsonb_array_elements(ad.fin_catalog(_base) -> 'categories') x
           where (x ->> 'nr_category')::bigint = _cat) = '6', 'grupo no catalogo';
end $$;

reset role;
rollback;
\o
\echo 'OK: 25_settings_gaps'
