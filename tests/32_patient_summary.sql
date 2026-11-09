-- ============================================================================
-- Abas da ficha: ad.patient_summary_get (agendamentos, financeiro, recibos e
-- plano de tratamento), com cada parte dependendo da permissao da tela dela.
--   Lia = administradora da empresa
--   Teo = recepcao (pacientes: so ler)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/32_patient_summary.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b5', 'lia.sum@test.local', '{"name": "Lia Sum"}'),
  ('00000000-0000-0000-0000-0000000000b6', 'teo.sum@test.local', '{"name": "Teo Sum"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b5","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Lia: consulta, orcamento aprovado e item realizado'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pb    jsonb;
  _pa    bigint;
  _prof  bigint;
  _nb    bigint;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Sum"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Rui Sum", "dt_birth": "1980-02-03",
           "vc_cpf": "529.982.247-25"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  _pb := _base || jsonb_build_object('nr_patient', _pa);
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Ana"}'::jsonb) ->> 'nr_professional')::bigint;
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'it_type', 1, 'nr_patient', _pa,
            'nr_professional', _prof, 'dh_start', now() + interval '2 days', 'dh_end', now() + interval '2 days 1 hour'));
  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'dt_budget', '2030-03-04',
          'items', '[{"vc_description": "Restauração", "vl_unit": 200}, {"vc_description": "Limpeza", "vl_unit": 100}]'::jsonb)))
          -> 'budget' ->> 'nr_budget')::bigint;
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 2,
            'dt_first_due', '2020-01-10', 'it_payment_method', 2));
  perform ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'Restauração feita.',
            'nr_budget', _nb, 'nr_item', 1));

  perform pg_temp.expect_error('patient_summary_get', _base || '{"nr_patient": 999}'::jsonb, 'PATIENT_NOT_FOUND');
  _r := ad.patient_summary_get(_pb);
  assert (_r -> 'permission' ->> 'id_agenda')::boolean and (_r -> 'permission' ->> 'id_finance')::boolean, 'admin ve tudo';
  assert jsonb_array_length(_r -> 'appointments') = 1 and _r -> 'appointments' -> 0 ->> 'vc_professional' = 'Dra. Ana',
    'agendamento';
  assert jsonb_array_length(_r -> 'finance' -> 'entries') = 2, 'duas parcelas';
  assert (_r -> 'finance' -> 'totals' ->> 'vl_open')::numeric = 300
     and (_r -> 'finance' -> 'totals' ->> 'qt_overdue')::int = 2, 'totais (parcelas vencidas em 2020)';
  assert jsonb_array_length(_r -> 'plan') = 1 and (_r -> 'plan' -> 0 ->> 'qt_items')::int = 2
     and (_r -> 'plan' -> 0 ->> 'qt_done')::int = 1, 'plano com 1 de 2 realizado';
  assert _r -> 'plan' -> 0 -> 'items' -> 0 ->> 'dt_done' is not null
     and _r -> 'plan' -> 0 -> 'items' -> 1 ->> 'dt_done' is null, 'item realizado marcado';

  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'teo.sum@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Teo: so PATIENTS, as partes vem vazias'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b6","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _r jsonb;
begin
  _r := ad.patient_summary_get(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint,
          'nr_branch', 1, 'nr_patient', current_setting('test.nr_patient')::bigint));
  assert _r -> 'appointments' = 'null'::jsonb and _r -> 'finance' = 'null'::jsonb and _r -> 'plan' = 'null'::jsonb, 'sem permissao';
  assert not (_r -> 'permission' ->> 'id_finance')::boolean, 'permissao';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.patient_summary_get('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou patient_summary_get';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 32_patient_summary'
