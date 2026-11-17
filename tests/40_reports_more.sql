-- ============================================================================
-- Relatorios novos (ad.report_get + od.fn_report_*): agenda, pacientes,
-- tratamentos e geral.
--   Eli = administradora da empresa
--   Bia = recepcao (relatorios: ler; financeiro, orcamentos e logs: nao)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/40_reports_more.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'eli.rm@test.local', '{"name": "Eli RM"}'),
  ('00000000-0000-0000-0000-0000000000d2', 'bia.rm@test.local', '{"name": "Bia RM"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Eli: empresa, pacientes e profissional'
do $$
declare
  _ca   bigint;
  _base jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica RM"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  perform set_config('test.ana', (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana RM", "dt_birth": "1990-03-15", "vc_cpf": "52998224725", "vc_mobile": "41999990001"}'::jsonb)
                                  ->> 'nr_patient'), false);
  perform set_config('test.beto', (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Beto RM", "dt_birth": "1985-07-01", "vc_cpf": "11144477735", "vc_mobile": "41999990002"}'::jsonb)
                                   ->> 'nr_patient'), false);
  perform set_config('test.caio', (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Caio RM", "dt_birth": "2000-01-01", "vc_cpf": "12345678909", "vc_mobile": "41999990003"}'::jsonb) ->> 'nr_patient'), false);
  perform set_config('test.prof', (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dr. Ivo"}'::jsonb)
                                   ->> 'nr_professional'), false);
  perform ad.fin_setup(_base);
end $$;

-- dados de apoio gravados direto (fora do papel authenticated)
reset role;
create temp table t (c bigint, ana bigint, beto bigint, caio bigint, prof bigint, usr bigint) on commit drop;
insert into t select current_setting('test.c')::bigint, current_setting('test.ana')::bigint, current_setting('test.beto')::bigint,
                     current_setting('test.caio')::bigint, current_setting('test.prof')::bigint,
                     (select nr_user from ad.app_user where uu_auth = '00000000-0000-0000-0000-0000000000d1');

update od.patient p set it_gender = 2, vc_city = 'Curitiba', vc_state = 'PR', vc_district = 'Centro',
                        dt_return_alert = '2030-03-20', vc_return_alert = 'Revisão'
  from t where p.nr_company = t.c and p.nr_patient = t.ana;
update od.patient p set it_gender = 1, vc_city = 'Curitiba', vc_state = 'PR', vc_district = 'Batel'
  from t where p.nr_company = t.c and p.nr_patient = t.beto;

insert into od.appointment (nr_company, nr_branch, nr_appointment, it_type, nr_patient, nr_professional, dh_start, dh_end, it_status, it_origin)
select t.c, 1, v.n, 1, x.p, t.prof, v.d0, v.d0 + interval '30 minutes', v.st, v.orig
  from t, (values (1, 'ana',  timestamptz '2030-03-05 10:00-03', 5::smallint, 1::smallint),
                  (2, 'ana',  timestamptz '2030-03-12 10:00-03', 7::smallint, 1::smallint),
                  (3, 'beto', timestamptz '2030-03-19 10:00-03', 90::smallint, 1::smallint),
                  (4, 'beto', timestamptz '2030-03-25 10:00-03', 2::smallint, 2::smallint),
                  (5, 'ana',  timestamptz '2026-01-12 10:00-03', 5::smallint, 1::smallint),
                  (6, 'caio', timestamptz '2026-01-10 10:00-03', 5::smallint, 1::smallint)) v(n, who, d0, st, orig)
     , lateral (select case v.who when 'ana' then t.ana when 'beto' then t.beto else t.caio end as p) x;

insert into od.budget (nr_company, nr_branch, nr_budget, nr_patient, nr_professional, vc_title, dt_budget, dt_valid, vl_gross, vl_total, it_status, dh_accepted)
select t.c, 1, v.n, v.p, t.prof, v.ti, v.d, v.d + 30, v.vl, v.vl, v.st, v.acc
  from t, lateral (values (1, t.ana, 'Tratamento Ana', date '2030-03-02', 300::numeric, 3::smallint, timestamptz '2030-03-03 12:00-03'),
                          (2, t.beto, 'Tratamento Beto', date '2030-03-04', 150::numeric, 4::smallint, null::timestamptz),
                          (3, t.caio, 'Tratamento Caio', date '2030-03-06', 50::numeric, 1::smallint, null::timestamptz)) v(n, p, ti, d, vl, st, acc);
insert into od.budget_item (nr_company, nr_branch, nr_budget, nr_item, vc_description, vc_tooth, qt_quantity, vl_unit, vl_total, dt_done)
select t.c, 1, 1, v.i, v.ds, '11', 1, v.vl, v.vl, v.dn
  from t, (values (1, 'Limpeza', 200::numeric, date '2030-03-04'), (2, 'Restauração', 100::numeric, null::date)) v(i, ds, vl, dn);

select set_config('test.cat', od.fn_fin_category_ensure((select c from t), 1, 'Tratamentos', 1::smallint, null::smallint,
                                                        (select usr from t))::text, false);
insert into od.fin_entry (nr_company, nr_branch, nr_entry, it_kind, nr_category, nr_patient, nr_budget, vc_description, vl_amount,
                          dt_due, dt_competence, it_status, dt_paid, vl_paid, nr_account)
select t.c, 1, v.n, 1, current_setting('test.cat')::bigint, v.p, v.b, v.ds, v.vl, v.due, v.comp, v.st, v.paid, v.vp,
       case when v.st = 2 then (select min(nr_account) from od.fin_account where nr_company = t.c) end
  from t, lateral (values (900, t.ana, 1::bigint, 'Tratamento Ana', 300::numeric, date '2030-03-10', date '2030-03-10', 2::smallint,
                           date '2030-03-10', 300::numeric),
                          (901, t.caio, null::bigint, 'Consulta Caio', 50::numeric, date '2030-03-15', date '2030-03-15', 1::smallint,
                           null::date, null::numeric),
                          (902, t.ana, null::bigint, 'Parcela vencida', 80::numeric, date '2026-01-05', date '2026-01-05', 1::smallint,
                           null::date, null::numeric)) v(n, p, b, ds, vl, due, comp, st, paid, vp);

insert into od.health_plan (nr_company, nr_branch, nr_plan, vc_name) select c, 1, 1, 'Uni RM' from t;
insert into od.health_guide (nr_company, nr_branch, nr_guide, nr_plan, nr_patient, nr_professional, dt_service, vl_total, it_status,
                             vl_paid, vl_denied, dt_paid, nr_entry, dt_invoiced)
select t.c, 1, v.n, 1, t.beto, t.prof, date '2030-03-08', v.vl, v.st, v.vp, v.vd, v.dp,
       case when v.st = 3 then 900 end, case when v.st = 3 then date '2030-03-20' end
  from t, (values (1, 200::numeric, 3::smallint, 180::numeric, 20::numeric, date '2030-04-01'),
                  (2, 100::numeric, 1::smallint, null::numeric, null::numeric, null::date)) v(n, vl, st, vp, vd, dp);

insert into od.specialty (nr_company, nr_branch, nr_specialty, vc_name) select c, 1, 900, 'Implantodontia RM' from t;
insert into od.procedure (nr_company, nr_branch, nr_procedure, vc_name, nr_specialty) select c, 1, 900, 'Implante unitário', 900 from t;
insert into od.clinical_evolution (nr_company, nr_branch, nr_patient, nr_evolution, dh_evolution, nr_professional, vc_text, vc_tooth,
                                   nr_procedure, it_status, nr_user)
select c, 1, beto, 900, timestamptz '2030-03-09 15:00-03', prof, 'Implante instalado.', '36', 900, 1, usr from t;

insert into ad.access_log (nr_user, nr_company, nr_branch, it_app, dh_access)
select usr, c, 1, v.app, v.dh from t, (values (1::smallint, timestamptz '2030-03-01 09:00-03'),
                                               (2::smallint, timestamptz '2030-03-02 09:00-03')) v(app, dh);
insert into ad.event_log (nr_company, nr_branch, nr_user, uu_screen, vc_action, vc_entity, vc_summary, dh_event)
select c, 1, usr, '0d6a1f3e-1b2c-4d5e-8f90-000000000006', v.a, 'patient', 'Teste', timestamptz '2030-03-03 10:00-03'
  from t, (values ('CREATE'), ('UPDATE')) v(a);

insert into od.whatsapp_message (nr_company, nr_branch, nr_message, it_kind, nr_patient, dt_ref, vc_to, vc_template, it_status, vc_reply)
select c, 1, v.n, 1, ana, current_date - v.n, '5541999990000', 'lembrete', v.st, v.rp
  from t, (values (1, 2::smallint, 'CONFIRM'), (2, 9::smallint, null)) v(n, st, rp);
insert into od.notify_message (nr_company, nr_branch, nr_message, it_channel, it_kind, nr_patient, dt_ref, vc_to, tx_body, it_status, dh_confirmed, uu_token)
select c, 1, 1, 1, 1, ana, current_date, 'ana@test.local', 'Lembrete', 2, now(), gen_random_uuid() from t;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Eli: relatorios novos'
do $$
declare
  _r    jsonb;
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
  _mar  jsonb := jsonb_build_object('dt_start', '2030-03-01', 'dt_end', '2030-03-31');
  _jan  jsonb := jsonb_build_object('dt_start', '2026-01-01', 'dt_end', '2026-01-31');
  _now  jsonb := jsonb_build_object('dt_start', current_date - 1, 'dt_end', current_date + 1);
  _pr   bigint;
begin
  -- agenda
  _r := ad.report_get(_base || _mar || '{"vc_report": "appointments"}'::jsonb) -> 'summary';
  assert (_r ->> 'qt_total')::int = 4 and (_r ->> 'qt_done')::int = 1 and (_r ->> 'qt_no_show')::int = 1
     and (_r ->> 'qt_cancelled')::int = 1 and (_r ->> 'qt_confirmed')::int = 1 and (_r ->> 'qt_online')::int = 1,
    'agendamentos: ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "first_visit"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_first')::int = 1 and _r -> 'rows' -> 0 ->> 'vc_patient' = 'Beto RM',
    'primeira consulta (a cancelada nao conta): ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "return_alerts"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_patients')::int = 1 and (_r -> 'summary' ->> 'qt_scheduled')::int = 1
     and _r -> 'rows' -> 0 ->> 'vc_return_alert' = 'Revisão', 'alertas de retorno: ' || _r::text;

  -- pacientes
  _r := ad.report_get(_base || _mar || '{"vc_report": "age_groups"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_patients')::int = 3 and jsonb_array_length(_r -> 'rows') = 3
     and (_r -> 'rows' -> 0 ->> 'it_band')::int = 3 and (_r -> 'rows' -> 2 ->> 'qt_male')::int = 1, 'faixa etaria: ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "location"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_cities')::int = 1 and (_r -> 'summary' ->> 'qt_no_address')::int = 1
     and jsonb_array_length(_r -> 'rows') = 3, 'localizacao: ' || _r::text;
  _r := ad.report_get(_base || _jan || '{"vc_report": "last_visit"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_patients')::int = 1 and _r -> 'rows' -> 0 ->> 'vc_patient' = 'Caio RM',
    'ultimo agendamento (Ana tem consulta futura): ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "budgets"}'::jsonb) -> 'summary';
  assert (_r ->> 'qt_total')::int = 3 and (_r ->> 'qt_approved')::int = 1 and (_r ->> 'qt_refused')::int = 1
     and (_r ->> 'qt_open')::int = 1 and (_r ->> 'vl_approved')::numeric = 300 and (_r ->> 'pc_conversion')::numeric = 33.3,
    'orcamentos: ' || _r::text;
  _r := ad.report_get(_base || _jan || '{"vc_report": "overdue"}'::jsonb);
  assert (_r -> 'summary' ->> 'vl_total')::numeric = 80 and (_r -> 'rows' -> 0 ->> 'qt_days_late')::int > 0,
    'cobranca: ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "health_plans"}'::jsonb);
  assert _r -> 'rows' -> 0 ->> 'vc_plan' = 'Uni RM' and (_r -> 'rows' -> 0 ->> 'qt_guides')::int = 2
     and (_r -> 'rows' -> 0 ->> 'qt_open')::int = 1 and (_r -> 'summary' ->> 'vl_paid')::numeric = 180
     and (_r -> 'summary' ->> 'vl_denied')::numeric = 20, 'convenios: ' || _r::text;

  -- tratamentos
  _r := ad.report_get(_base || _mar || '{"vc_report": "open_treatments"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_budgets')::int = 1 and (_r -> 'summary' ->> 'vl_pending')::numeric = 100
     and (_r -> 'rows' -> 0 ->> 'qt_done')::int = 1, 'tratamentos em aberto: ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "pending_procedures"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_items')::int = 1 and _r -> 'rows' -> 0 ->> 'vc_procedure' = 'Restauração',
    'procedimentos nao executados: ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "revenue"}'::jsonb);
  assert (_r -> 'summary' ->> 'vl_total')::numeric = 350 and (_r -> 'summary' ->> 'vl_received')::numeric = 300
     and (_r -> 'summary' ->> 'vl_open')::numeric = 50 and _r -> 'by_professional' @> '[{"vc_professional": "Dr. Ivo"}]',
    'faturamento: ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "implants"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_procedures')::int = 1 and _r -> 'rows' -> 0 ->> 'vc_tooth' = '36', 'implantes: ' || _r::text;

  -- geral
  _r := ad.report_get(_base || _mar || '{"vc_report": "user_access"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_access')::int = 2 and (_r -> 'rows' -> 0 ->> 'qt_android')::int = 1, 'acessos: ' || _r::text;
  _r := ad.report_get(_base || _mar || '{"vc_report": "user_actions"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_events')::int = 2 and (_r -> 'rows' -> 0 ->> 'qt_create')::int = 1, 'acoes: ' || _r::text;
  _r := ad.report_get(_base || _now || '{"vc_report": "messages"}'::jsonb) -> 'summary';
  assert (_r ->> 'qt_total')::int = 3 and (_r ->> 'qt_sent')::int = 2 and (_r ->> 'qt_error')::int = 1
     and (_r ->> 'qt_confirmed')::int = 2, 'mensagens: ' || _r::text;

  -- Bia: so relatorios
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000011', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'bia.rm@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Bia: agenda sim; financeiro, orcamentos e logs nao'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1,
                                    'dt_start', '2030-03-01', 'dt_end', '2030-03-31');
begin
  assert (ad.report_get(_base || '{"vc_report": "appointments"}'::jsonb) -> 'summary' ->> 'qt_total')::int = 4, 'le agenda';
  perform pg_temp.expect_error('report_get', _base || '{"vc_report": "revenue"}'::jsonb, 'REPORT_FORBIDDEN');
  perform pg_temp.expect_error('report_get', _base || '{"vc_report": "budgets"}'::jsonb, 'REPORT_FORBIDDEN');
  perform pg_temp.expect_error('report_get', _base || '{"vc_report": "user_actions"}'::jsonb, 'REPORT_FORBIDDEN');
end $$;

reset role;
rollback;
\o
\echo 'OK: 40_reports_more'
