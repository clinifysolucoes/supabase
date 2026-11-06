-- ============================================================================
-- Orcamentos: ad.budget_save / budget_get / budget_list / budget_status
-- (desconto maximo e aprovacao do administrador, aprovacao do paciente com as
-- contas a receber, recusa, cancelamento e reabertura).
--   Mel = administradora da empresa
--   Ivo = recepcao (orcamentos: ler, criar e alterar)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/24_budgets.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a7', 'mel.orc@test.local', '{"name": "Mel Orc"}'),
  ('00000000-0000-0000-0000-0000000000a8', 'ivo.orc@test.local', '{"name": "Ivo Orc"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a7","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Mel: cadastros e orcamento'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _ana   bigint;
  _sp    bigint;
  _imp   bigint;
  _nb    bigint;
  _prof  bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Orc"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Orc", "dt_birth": "1990-01-01",
           "vc_cpf": "529.982.247-25"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  _ana := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Ana"}'::jsonb) ->> 'nr_professional')::bigint;
  _sp := (ad.specialty_save(_base || '{"vc_action": "I", "vc_name": "Implantodontia"}'::jsonb) ->> 'nr_specialty')::bigint;
  _imp := (ad.procedure_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Implante unitário', 'nr_specialty', _sp,
            'qt_minutes', 60, 'vl_current_price', 2500)) ->> 'nr_procedure')::bigint;
  perform set_config('test.nr_procedure', _imp::text, false);

  -- validacoes
  perform pg_temp.expect_error('budget_save', _base || '{"vc_action": "I"}'::jsonb, 'BUDGET_ITEMS_REQUIRED');
  perform pg_temp.expect_error('budget_save', _base || '{"vc_action": "I", "nr_patient": 999, "items": [{"vc_description": "X"}]}'::jsonb,
            'BUDGET_PATIENT_INVALID');
  perform pg_temp.expect_error('budget_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'items', jsonb_build_array(jsonb_build_object('nr_procedure', 999))), 'BUDGET_PROCEDURE_INVALID');
  perform pg_temp.expect_error('budget_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'items', '[{"vc_description": "X", "qt_quantity": 0}]'::jsonb), 'BUDGET_ITEM_INVALID');
  perform pg_temp.expect_error('budget_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'dt_budget', '2030-03-04', 'dt_valid', '2030-03-01', 'items', '[{"vc_description": "X"}]'::jsonb), 'BUDGET_DATE_INVALID');

  -- implante (valor cobrado hoje) x2 + clareamento livre 500; desconto de 5% (dentro do maximo de 10%)
  _r := ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _ana,
          'vc_title', 'Reabilitação', 'dt_budget', '2030-03-04', 'pc_discount', 5, 'qt_installments', 3,
          'items', jsonb_build_array(
            jsonb_build_object('nr_procedure', _imp, 'vc_tooth', '16', 'qt_quantity', 2),
            jsonb_build_object('vc_description', 'Clareamento', 'vl_unit', 500))));
  _nb := (_r -> 'budget' ->> 'nr_budget')::bigint;
  perform set_config('test.nr_budget', _nb::text, false);
  assert (_r -> 'budget' ->> 'vl_gross')::numeric = 5500 and (_r -> 'budget' ->> 'vl_discount')::numeric = 275
     and (_r -> 'budget' ->> 'vl_total')::numeric = 5225, 'totais';
  assert (_r -> 'budget' ->> 'it_status')::int = 1, 'em aberto';
  assert _r -> 'budget' ->> 'dt_valid' = '2030-04-03', 'validade padrao de 30 dias';
  assert jsonb_array_length(_r -> 'items') = 2 and _r -> 'items' -> 0 ->> 'vc_description' = 'Implante unitário'
     and (_r -> 'items' -> 0 ->> 'vl_total')::numeric = 5000, 'itens';
  assert (_r ->> 'pc_max_discount')::numeric = 10 and (_r -> 'permission' ->> 'id_approve_discount')::boolean, 'permissoes';

  -- admin com 20% ja aprova
  _r := ad.budget_save(_base || jsonb_build_object('vc_action', 'U', 'nr_budget', _nb, 'pc_discount', 20));
  assert (_r -> 'budget' ->> 'it_status')::int = 1 and (_r -> 'budget' ->> 'id_discount_approved')::boolean
     and _r -> 'budget' ->> 'vc_user_discount' = 'Mel Orc', 'admin aprova o proprio desconto';
  perform pg_temp.expect_error('budget_save', _base || jsonb_build_object('vc_action', 'U', 'nr_budget', _nb,
            'vl_discount', 6000), 'BUDGET_DISCOUNT_INVALID');
  perform ad.budget_save(_base || jsonb_build_object('vc_action', 'U', 'nr_budget', _nb, 'pc_discount', 5));

  -- lista
  _r := ad.budget_list(_base || jsonb_build_object('nr_patient', _pa));
  assert jsonb_array_length(_r -> 'budgets') = 1 and (_r -> 'budgets' -> 0 ->> 'qt_items')::int = 2, 'lista do paciente';
  perform pg_temp.expect_error('budget_list', _base || '{"vc_status": "x"}'::jsonb, 'BUDGET_FILTER_INVALID');

  -- Ivo: recepcao com orcamentos (ler, criar, alterar)
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000010',
                                                          'id_read', true, 'id_create', true, 'id_update', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ivo.orc@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));
end $$;

\echo '== Ivo: desconto acima do maximo aguarda o administrador'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  _r := ad.budget_save(_base || jsonb_build_object('vc_action', 'U', 'nr_budget', current_setting('test.nr_budget')::bigint,
          'pc_discount', 15));
  assert (_r -> 'budget' ->> 'it_status')::int = 2 and not (_r -> 'permission' ->> 'id_approve_discount')::boolean,
    'aguardando aprovacao';
  perform pg_temp.expect_error('budget_status', _base || jsonb_build_object('nr_budget', current_setting('test.nr_budget')::bigint,
            'vc_action', 'APPROVE_DISCOUNT'), 'BUDGET_DISCOUNT_FORBIDDEN');
  perform pg_temp.expect_error('budget_status', _base || jsonb_build_object('nr_budget', current_setting('test.nr_budget')::bigint,
            'vc_action', 'ACCEPT'), 'BUDGET_STATUS_INVALID');
end $$;

\echo '== Mel: aprova o desconto; paciente aprova e gera as contas'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a7","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _ca   bigint := current_setting('test.nr_company')::bigint;
  _nb   bigint := current_setting('test.nr_budget')::bigint;
  _base jsonb  := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
  _nb2  bigint;
begin
  _r := ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'APPROVE_DISCOUNT'));
  assert (_r -> 'budget' ->> 'it_status')::int = 1 and (_r -> 'budget' ->> 'id_discount_approved')::boolean, 'desconto aprovado';
  -- vencido nao aprova
  perform ad.budget_save(_base || jsonb_build_object('vc_action', 'U', 'nr_budget', _nb, 'dt_valid', '2030-03-05'));
  -- (a validade e 2030: hoje esta dentro)
  _r := ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 3,
          'dt_first_due', '2030-03-10', 'it_payment_method', 2));
  assert (_r -> 'budget' ->> 'it_status')::int = 3 and (_r ->> 'qt_entries')::int = 3, 'aprovado com 3 parcelas';
  assert jsonb_array_length(_r -> 'entries') = 3 and (select sum((e ->> 'vl_amount')::numeric) from jsonb_array_elements(_r -> 'entries') e)
           = (_r -> 'budget' ->> 'vl_total')::numeric, 'parcelas somam o total';
  assert (select count(*) from od.fin_entry where nr_company = _ca and nr_budget = _nb and it_kind = 1
            and nr_patient = current_setting('test.nr_patient')::bigint and dt_due = '2030-05-10') = 1, 'terceira parcela';
  perform pg_temp.expect_error('budget_save', _base || jsonb_build_object('vc_action', 'U', 'nr_budget', _nb, 'vc_title', 'x'),
            'BUDGET_STATUS_INVALID');

  -- com parcela paga nao cancela; sem pagamento cancela as contas
  perform ad.fin_setup(_base);
  perform ad.fin_entry_settle(_base || jsonb_build_object('vc_action', 'PAY',
            'nr_entry', (select min(nr_entry) from od.fin_entry where nr_company = _ca and nr_budget = _nb),
            'nr_account', (select min(nr_account) from od.fin_account where nr_company = _ca)));
  perform pg_temp.expect_error('budget_status', _base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'CANCEL'),
            'BUDGET_HAS_PAYMENTS');

  -- outro orcamento: recusa, reabre, cancela
  _r := ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', current_setting('test.nr_patient')::bigint,
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', current_setting('test.nr_procedure')::bigint))));
  _nb2 := (_r -> 'budget' ->> 'nr_budget')::bigint;
  assert (_r -> 'budget' ->> 'vl_total')::numeric = 2500, 'valor cobrado hoje como padrao';
  _r := ad.budget_status(_base || jsonb_build_object('nr_budget', _nb2, 'vc_action', 'REFUSE'));
  assert (_r -> 'budget' ->> 'it_status')::int = 4, 'recusado';
  _r := ad.budget_status(_base || jsonb_build_object('nr_budget', _nb2, 'vc_action', 'REOPEN'));
  assert (_r -> 'budget' ->> 'it_status')::int = 1, 'reaberto';
  _r := ad.budget_status(_base || jsonb_build_object('nr_budget', _nb2, 'vc_action', 'CANCEL'));
  assert (_r -> 'budget' ->> 'it_status')::int = 90, 'cancelado';
  perform pg_temp.expect_error('budget_status', _base || jsonb_build_object('nr_budget', _nb2, 'vc_action', 'X'),
            'BUDGET_ACTION_INVALID');

  _r := ad.budget_list(_base || '{"vc_status": "accepted"}'::jsonb);
  assert jsonb_array_length(_r -> 'budgets') = 1 and (_r -> 'totals' ->> 'qt_accepted')::int = 1, 'filtro aprovados';
  assert exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'budget'
                    and e.vc_summary = format('Orçamento %s: aprovado pelo paciente', _nb)), 'log';
  assert not exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'budget'
                        and e.js_detail::text like '%Ana Orc%'), 'log sem nome do paciente';
  -- configuracoes
  perform pg_temp.expect_error('settings_save', _base || '{"pc_budget_max_discount": 101}'::jsonb, 'SETTINGS_BUDGET_INVALID');
  perform ad.settings_save(_base || '{"pc_budget_max_discount": 25, "qt_budget_valid_days": 15}'::jsonb);
  assert (ad.settings_get(_base) -> 'settings' ->> 'qt_budget_valid_days')::int = 15, 'validade gravada';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.budget_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou budget_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 24_budgets'
