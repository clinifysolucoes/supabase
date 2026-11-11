-- ============================================================================
-- Relatorios (ad.report_get): faltas e desmarcacoes, aniversariantes,
-- procedimentos executados e pagamentos e comissoes.
--   Eli = administradora da empresa
--   Bia = recepcao (relatorios: ler; financeiro: nao)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/33_reports.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c7', 'eli.rep@test.local', '{"name": "Eli Rep"}'),
  ('00000000-0000-0000-0000-0000000000c8', 'bia.rep@test.local', '{"name": "Bia Rep"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c7","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Eli: dados e relatorios'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _pb    bigint;
  _prof  bigint;
  _a1    bigint;
  _a2    bigint;
  _a3    bigint;
  _nb    bigint;
  _per   jsonb;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Rep"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Ana Rep', 'dt_birth', '1990-03-15',
           'vc_cpf', '529.982.247-25', 'vc_mobile', '41999990000')) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Beto Rep', 'dt_birth', '1985-07-01',
           'vc_cpf', '111.444.777-35')) ->> 'nr_patient')::bigint;
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Rosa"}'::jsonb) ->> 'nr_professional')::bigint;
  _per := jsonb_build_object('dt_start', '2030-03-01', 'dt_end', '2030-03-31');

  perform set_config('test.nr_pa', _pa::text, false);
  perform set_config('test.nr_pb', _pb::text, false);
  perform set_config('test.nr_prof', _prof::text, false);
  perform ad.fin_setup(_base);
end $$;

-- dados de apoio gravados direto (fora do papel authenticated)
reset role;
insert into od.appointment (nr_company, nr_branch, nr_appointment, it_type, nr_patient, nr_professional, dh_start, dh_end, it_status)
select current_setting('test.nr_company')::bigint, 1, v.n, 1, v.p, current_setting('test.nr_prof')::bigint, v.d0, v.d1, v.st
  from (values (1, current_setting('test.nr_pa')::bigint, timestamptz '2030-03-05 10:00-03', timestamptz '2030-03-05 11:00-03', 5::smallint),
               (2, current_setting('test.nr_pa')::bigint, timestamptz '2030-03-12 10:00-03', timestamptz '2030-03-12 11:00-03', 7::smallint),
               (3, current_setting('test.nr_pb')::bigint, timestamptz '2030-03-19 10:00-03', timestamptz '2030-03-19 11:00-03', 90::smallint)) v(n, p, d0, d1, st);
select set_config('test.nr_cat', od.fn_fin_category_ensure(current_setting('test.nr_company')::bigint, 1, 'Comissões', 2::smallint, 2::smallint,
         (select nr_user from ad.app_user where uu_auth = '00000000-0000-0000-0000-0000000000c7'))::text, false);
insert into od.fin_entry (nr_company, nr_branch, nr_entry, it_kind, nr_category, nr_professional, vc_description, vl_amount, dt_due, dt_competence, it_status, dt_paid, vl_paid, nr_account)
values (current_setting('test.nr_company')::bigint, 1, 900, 2, current_setting('test.nr_cat')::bigint, current_setting('test.nr_prof')::bigint, 'Comissão Dra. Rosa', 75, '2030-04-10', '2030-03-05', 1, null, null, null),
       (current_setting('test.nr_company')::bigint, 1, 901, 2, current_setting('test.nr_cat')::bigint, current_setting('test.nr_prof')::bigint, 'Comissão Dra. Rosa', 25, '2030-04-10', '2030-03-20', 2, '2030-04-10', 25,
        (select min(nr_account) from od.fin_account where nr_company = current_setting('test.nr_company')::bigint));
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c7","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _r     jsonb;
  _ca    bigint := current_setting('test.nr_company')::bigint;
  _base  jsonb;
  _pa    bigint := current_setting('test.nr_pa')::bigint;
  _prof  bigint := current_setting('test.nr_prof')::bigint;
  _nb    bigint;
  _per   jsonb := jsonb_build_object('dt_start', '2030-03-01', 'dt_end', '2030-03-31');
  _pr    bigint;
begin
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);

  perform pg_temp.expect_error('report_get', _base || _per || '{"vc_report": "x"}'::jsonb, 'REPORT_INVALID');
  perform pg_temp.expect_error('report_get', _base || '{"vc_report": "no_show", "dt_start": "2030-01-01", "dt_end": "2031-06-01"}'::jsonb,
            'REPORT_PERIOD_INVALID');
  perform pg_temp.expect_error('report_get', _base || '{"vc_report": "no_show", "dt_start": "2030-03-10", "dt_end": "2030-03-01"}'::jsonb,
            'REPORT_PERIOD_INVALID');

  _r := ad.report_get(_base || _per || '{"vc_report": "no_show"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_total')::int = 3 and (_r -> 'summary' ->> 'qt_no_show')::int = 1
     and (_r -> 'summary' ->> 'qt_cancelled')::int = 1 and (_r -> 'summary' ->> 'pc_no_show')::numeric = 50, 'faltas: ' || (_r -> 'summary')::text;
  assert jsonb_array_length(_r -> 'rows') = 2 and _r -> 'rows' -> 0 ->> 'vc_patient' = 'Ana Rep', 'linhas de falta';
  assert (_r -> 'by_professional' -> 0 ->> 'qt_no_show')::int = 1, 'por profissional';
  assert (ad.report_get(_base || _per || jsonb_build_object('vc_report', 'no_show', 'nr_professional', 999)) -> 'summary' ->> 'qt_total')::int = 0,
    'filtro de profissional';

  _r := ad.report_get(_base || _per || '{"vc_report": "birthdays"}'::jsonb);
  assert jsonb_array_length(_r -> 'rows') = 1 and _r -> 'rows' -> 0 ->> 'vc_patient' = 'Ana Rep'
     and (_r -> 'rows' -> 0 ->> 'qt_age')::int = 40 and _r -> 'rows' -> 0 ->> 'dt_birthday' = '2030-03-15', 'aniversariante';
  _r := ad.report_get(_base || '{"vc_report": "birthdays", "dt_start": "2030-12-20", "dt_end": "2031-07-05"}'::jsonb);
  assert jsonb_array_length(_r -> 'rows') = 2, 'virada de ano pega os dois';

  -- procedimento executado: orcamento aprovado com item realizado na evolucao
  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'dt_budget', current_date,
          'items', '[{"vc_description": "Restauração", "vl_unit": 250}]'::jsonb))) -> 'budget' ->> 'nr_budget')::bigint;
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 1,
            'dt_first_due', current_date + 10, 'it_payment_method', 2));
  perform ad.clinical_evolution_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'vc_text', 'Feito.',
            'nr_professional', _prof, 'nr_budget', _nb, 'nr_item', 1, 'dh_evolution', now() - interval '1 hour'));
  _r := ad.report_get(_base || jsonb_build_object('vc_report', 'procedures', 'dt_start', current_date - 1, 'dt_end', current_date + 1));
  assert (_r -> 'summary' ->> 'qt_procedures')::int = 1 and (_r -> 'summary' ->> 'vl_total')::numeric = 250
     and _r -> 'rows' -> 0 ->> 'vc_procedure' = 'Restauração', 'procedimento executado';

  -- comissoes (gravadas acima): 75 a pagar e 25 pagos, competencia em marco
  _r := ad.report_get(_base || _per || '{"vc_report": "commissions"}'::jsonb);
  assert (_r -> 'summary' ->> 'vl_total')::numeric = 100 and (_r -> 'summary' ->> 'vl_paid')::numeric = 25
     and (_r -> 'summary' ->> 'vl_open')::numeric = 75, 'comissoes: ' || (_r -> 'summary')::text;

  -- Bia: relatorios sim, financeiro nao
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000011', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'bia.rep@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Bia: le relatorios, nao as comissoes'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1,
                                    'dt_start', '2030-03-01', 'dt_end', '2030-03-31');
begin
  assert (ad.report_get(_base || '{"vc_report": "no_show"}'::jsonb) -> 'summary' ->> 'qt_total')::int = 3, 'le faltas';
  perform pg_temp.expect_error('report_get', _base || '{"vc_report": "commissions"}'::jsonb, 'REPORT_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.report_get('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou report_get';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 33_reports'
