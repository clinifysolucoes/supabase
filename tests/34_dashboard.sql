-- ============================================================================
-- Dashboard Analitico (ad.dashboard_get): indicadores por parte, conforme a
-- permissao de cada tela.
--   Eva = administradora da empresa (ve tudo)
--   Ivo = recepcao (so AGENDA)
--   Gus = de outra empresa (nao ve a filial)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/34_dashboard.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'eva.dash@test.local', '{"name": "Eva Dash"}'),
  ('00000000-0000-0000-0000-0000000000d2', 'ivo.dash@test.local', '{"name": "Ivo Dash"}'),
  ('00000000-0000-0000-0000-0000000000d3', 'gus.dash@test.local', '{"name": "Gus Dash"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Eva: empresa, pacientes, profissional e financeiro'
do $$
declare
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _prof  bigint;
  _today date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Dash"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Ana Dash',
           'dt_birth', (_today - interval '30 years')::date, 'vc_cpf', '529.982.247-25', 'it_source', 4)) ->> 'nr_patient')::bigint;
  perform ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Beto Dash', 'dt_birth', (_today - interval '40 years 2 months')::date, 'vc_cpf', '111.444.777-35'));
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Lia"}'::jsonb) ->> 'nr_professional')::bigint;
  perform ad.fin_setup(_base);
  perform set_config('test.nr_pa', _pa::text, false);
  perform set_config('test.nr_prof', _prof::text, false);
end $$;

-- consultas de hoje e lancamentos gravados direto (fora do papel authenticated)
reset role;
do $$
declare
  _ca    bigint := current_setting('test.nr_company')::bigint;
  _pa    bigint := current_setting('test.nr_pa')::bigint;
  _prof  bigint := current_setting('test.nr_prof')::bigint;
  _today date := (now() at time zone 'America/Sao_Paulo')::date;
  _user  bigint := (select nr_user from ad.app_user where uu_auth = '00000000-0000-0000-0000-0000000000d1');
  _acc   bigint := (select min(nr_account) from od.fin_account where nr_company = current_setting('test.nr_company')::bigint);
  _rev   bigint;
  _exp   bigint;
begin
  insert into od.appointment (nr_company, nr_branch, nr_appointment, it_type, nr_patient, nr_professional, dh_start, dh_end, it_status, it_origin)
  select _ca, 1, v.n, 1, _pa, _prof, (_today + v.h) at time zone 'America/Sao_Paulo',
         (_today + v.h + interval '30 minutes') at time zone 'America/Sao_Paulo', v.st, v.o
    from (values (1, time '09:00', 5::smallint, 1::smallint),
                 (2, time '10:00', 7::smallint, 2::smallint),
                 (3, time '11:00', 90::smallint, 1::smallint)) v(n, h, st, o);
  _rev := od.fn_fin_category_ensure(_ca, 1, 'Tratamentos', 1::smallint, 1::smallint, _user);
  _exp := od.fn_fin_category_ensure(_ca, 1, 'Aluguel', 2::smallint, 1::smallint, _user);
  insert into od.fin_entry (nr_company, nr_branch, nr_entry, it_kind, nr_category, vc_description, vl_amount, dt_due, dt_competence,
                            it_status, dt_paid, vl_paid, nr_account)
  values (_ca, 1, 800, 1, _rev, 'Consulta', 300, _today, _today, 2, _today, 300, _acc),
         (_ca, 1, 801, 2, _exp, 'Aluguel', 100, _today, _today, 2, _today, 100, _acc),
         (_ca, 1, 802, 1, _rev, 'Parcela vencida', 50, _today - 1, _today - 1, 1, null, null, null),
         (_ca, 1, 803, 2, _exp, 'Luz', 80, _today + 3, _today + 3, 1, null, null, null);
end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Eva: indicadores'
do $$
declare
  _r    jsonb;
  _ca   bigint := current_setting('test.nr_company')::bigint;
  _base jsonb;
  _pa   bigint := current_setting('test.nr_pa')::bigint;
  _prof bigint := current_setting('test.nr_prof')::bigint;
  _nb   bigint;
  _pr   bigint;
begin
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);

  -- orcamento aprovado com o item realizado na evolucao
  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'dt_budget', current_date,
          'items', '[{"vc_description": "Restauração", "vl_unit": 250}]'::jsonb))) -> 'budget' ->> 'nr_budget')::bigint;
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 1,
            'dt_first_due', current_date + 10, 'it_payment_method', 2));
  perform ad.clinical_evolution_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'vc_text', 'Feito.',
            'nr_professional', _prof, 'nr_budget', _nb, 'nr_item', 1, 'dh_evolution', now() - interval '1 minute'));

  perform pg_temp.expect_error('dashboard_get', _base || '{"dt_start": "2030-03-10", "dt_end": "2030-03-01"}'::jsonb,
            'DASHBOARD_PERIOD_INVALID');
  perform pg_temp.expect_error('dashboard_get', _base || '{"dt_start": "2030-01-01", "dt_end": "2031-06-01"}'::jsonb,
            'DASHBOARD_PERIOD_INVALID');
  perform pg_temp.expect_error('dashboard_get', '{"nr_version": 1}'::jsonb, 'DASHBOARD_BRANCH_REQUIRED');

  _r := ad.dashboard_get(_base);   -- mes corrente
  assert (_r -> 'agenda' ->> 'qt_appointments')::int = 2 and (_r -> 'agenda' ->> 'qt_attended')::int = 1
     and (_r -> 'agenda' ->> 'qt_no_show')::int = 1 and (_r -> 'agenda' ->> 'qt_cancelled')::int = 1
     and (_r -> 'agenda' ->> 'pc_no_show')::numeric = 50 and (_r -> 'agenda' ->> 'qt_online')::int = 1
     and (_r -> 'agenda' ->> 'qt_today')::int = 2 and (_r -> 'agenda' ->> 'qt_today_confirmed')::int = 1,
    'agenda: ' || (_r -> 'agenda')::text;
  assert (_r -> 'patients' ->> 'qt_new')::int = 2 and (_r -> 'patients' ->> 'qt_new_prev')::int = 0
     and (_r -> 'patients' ->> 'qt_active')::int = 2 and (_r -> 'patients' ->> 'qt_birthdays_today')::int = 1
     and (_r -> 'patients' ->> 'qt_procedures')::int = 1
     and _r -> 'patients' -> 'top_procedures' -> 0 ->> 'vc_procedure' = 'Restauração'
     and jsonb_array_length(_r -> 'patients' -> 'by_source') = 2,
    'pacientes: ' || (_r -> 'patients')::text;
  assert (_r -> 'budgets' ->> 'qt_created')::int = 1 and (_r -> 'budgets' ->> 'qt_accepted')::int = 1
     and (_r -> 'budgets' ->> 'vl_accepted')::numeric = 250 and (_r -> 'budgets' ->> 'pc_conversion')::numeric = 100
     and (_r -> 'budgets' ->> 'qt_open')::int = 0,
    'orcamentos: ' || (_r -> 'budgets')::text;
  assert (_r -> 'finance' ->> 'vl_revenue')::numeric = 300 and (_r -> 'finance' ->> 'vl_expense')::numeric = 100
     and (_r -> 'finance' ->> 'vl_result')::numeric = 200 and (_r -> 'finance' ->> 'vl_overdue')::numeric = 50
     and (_r -> 'finance' ->> 'qt_overdue')::int = 1 and (_r -> 'finance' ->> 'vl_payable_week')::numeric = 80,
    'financeiro: ' || (_r -> 'finance')::text;
  assert jsonb_array_length(_r -> 'series') = 6
     and (_r -> 'series' -> 5 ->> 'vl_revenue')::numeric = 300 and (_r -> 'series' -> 5 ->> 'qt_attended')::int = 1
     and (_r -> 'series' -> 5 ->> 'qt_new_patients')::int = 2,
    'serie: ' || (_r -> 'series' -> 5)::text;

  -- Ivo: so a agenda
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000007', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ivo.dash@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Ivo: so a parte da agenda'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _r jsonb := ad.dashboard_get(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint,
                                                  'nr_branch', 1));
begin
  assert (_r -> 'agenda' ->> 'qt_attended')::int = 1, 'agenda visivel';
  assert jsonb_typeof(_r -> 'patients') = 'null' and jsonb_typeof(_r -> 'budgets') = 'null'
     and jsonb_typeof(_r -> 'finance') = 'null', 'partes sem permissao vem null';
  assert not (_r -> 'series' -> 5 ? 'vl_revenue') and (_r -> 'series' -> 5 ? 'qt_attended'), 'serie so com a agenda';
end $$;

\echo '== Gus: outra empresa nao ve a filial'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d3","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  perform ad.company_create('{"nr_version": 1, "vc_name": "Outra Dash"}'::jsonb);
  perform pg_temp.expect_error('dashboard_get', jsonb_build_object('nr_version', 1,
            'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1), 'DASHBOARD_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.dashboard_get('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou dashboard_get';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 34_dashboard'
