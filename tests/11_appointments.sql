-- ============================================================================
-- Agenda, parte 2: consultas e compromissos (ad.appointment_list / ad.appointment_save).
--   Kim = administradora da empresa
--   Lia = perfil "Recepcao": AGENDA ler + criar (sem alterar)
-- Filial no fuso America/Sao_Paulo (UTC-3): 03/11/2026 09:00 local = 12:00 UTC.
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/11_appointments.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

\echo '== setup: usuarios'
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-000000000081', 'kim.ag@test.local', '{"name": "Kim Agenda"}'),
  ('00000000-0000-0000-0000-000000000082', 'lia.ag@test.local', '{"name": "Lia Agenda"}');

-- ----------------------------------------------------------------------------
\echo '== Kim: consultas, compromissos, conflito e situacao'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000081","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  perform ad.appointment_save(p_json);
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

do $$
declare
  _r    jsonb;
  _ca   bigint;
  _pa   bigint;
  _pb   bigint;
  _ana  bigint;
  _bia  bigint;
  _a1   bigint;
  _a2   bigint;
  _a3   bigint;
  _prof bigint;
  _uu   uuid := '0d6a1f3e-1b2c-4d5e-8f90-000000000007';
  _base jsonb;
  _ap   jsonb;
begin
  _r  := ad.company_create('{"nr_version": 1, "vc_name": "Clinica Consultas"}'::jsonb);
  _ca := (_r ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);

  _pa := (ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', 'Paciente Um', 'dt_birth', '1990-01-01', 'vc_cpf', '12345678062', 'vc_mobile', '11987654321',
           'dt_return_alert', '2026-11-04', 'vc_return_alert', 'Revisão')) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', 'Paciente Dois', 'dt_birth', '1985-01-01', 'vc_cpf', '23456789173')) ->> 'nr_patient')::bigint;
  _ana := (ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', 'Dra. Ana')) ->> 'nr_professional')::bigint;
  _bia := (ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
           'vc_name', 'Dra. Bia')) ->> 'nr_professional')::bigint;

  _base := jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1);

  -- consulta 09:00-10:00 com a Ana
  _a1 := (ad.appointment_save(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _ana,
           'dh_start', '2026-11-03T09:00:00-03:00', 'dh_end', '2026-11-03T10:00:00-03:00',
           'vc_notes', 'Primeira consulta')) ->> 'nr_appointment')::bigint;
  assert _a1 = 1, 'nr_appointment sequencial';
  assert (select dh_start = '2026-11-03 12:00:00+00'::timestamptz and it_status = 1 and nr_user_created is not null
            from od.appointment where nr_company = _ca and nr_appointment = _a1), 'gravado em UTC, agendado, quem agendou';

  -- validacoes
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_professional', _ana,
            'dh_start', '2026-11-03T11:00:00-03:00', 'dh_end', '2026-11-03T12:00:00-03:00'), 'APPOINTMENT_PATIENT_REQUIRED');
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pa,
            'dh_start', '2026-11-03T11:00:00-03:00', 'dh_end', '2026-11-03T12:00:00-03:00'), 'APPOINTMENT_PROFESSIONAL_REQUIRED');
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', 999, 'nr_professional', _ana,
            'dh_start', '2026-11-03T11:00:00-03:00', 'dh_end', '2026-11-03T12:00:00-03:00'), 'APPOINTMENT_PATIENT_INVALID');
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', 999,
            'dh_start', '2026-11-03T11:00:00-03:00', 'dh_end', '2026-11-03T12:00:00-03:00'), 'APPOINTMENT_PROFESSIONAL_INVALID');
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _ana, 'nr_procedure', 999,
            'dh_start', '2026-11-03T11:00:00-03:00', 'dh_end', '2026-11-03T12:00:00-03:00'), 'APPOINTMENT_PROCEDURE_INVALID');
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _ana,
            'dh_start', '2026-11-03T11:00:00-03:00', 'dh_end', '2026-11-03T10:00:00-03:00'), 'APPOINTMENT_PERIOD_INVALID');
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _ana,
            'dh_start', 'amanha', 'dh_end', '2026-11-03T10:00:00-03:00'), 'APPOINTMENT_VALUE_INVALID');
  perform pg_temp.expect_error(_base || jsonb_build_object('it_type', 2, 'nr_professional', _ana,
            'dh_start', '2026-11-03T11:00:00-03:00', 'dh_end', '2026-11-03T12:00:00-03:00'), 'APPOINTMENT_TITLE_REQUIRED');
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _ana, 'it_status', 8,
            'dh_start', '2026-11-03T11:00:00-03:00', 'dh_end', '2026-11-03T12:00:00-03:00'), 'APPOINTMENT_STATUS_INVALID');

  -- conflito: mesma profissional no mesmo horario; outra profissional pode; encaixe pode
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pb, 'nr_professional', _ana,
            'dh_start', '2026-11-03T09:30:00-03:00', 'dh_end', '2026-11-03T10:30:00-03:00'), 'APPOINTMENT_CONFLICT');
  begin
    perform ad.appointment_save(_base || jsonb_build_object('nr_patient', _pb, 'nr_professional', _ana,
              'dh_start', '2026-11-03T09:30:00-03:00', 'dh_end', '2026-11-03T10:30:00-03:00'));
  exception when others then
    assert sqlerrm like '%"Time": "03/11 09:00"%', 'conflito mostra o horario no fuso da filial, veio ' || sqlerrm;
  end;
  _a2 := (ad.appointment_save(_base || jsonb_build_object('nr_patient', _pb, 'nr_professional', _bia,
           'dh_start', '2026-11-03T09:30:00-03:00', 'dh_end', '2026-11-03T10:30:00-03:00')) ->> 'nr_appointment')::bigint;
  perform ad.appointment_save(_base || jsonb_build_object('nr_patient', _pb, 'nr_professional', _ana, 'id_fit_in', true,
            'dh_start', '2026-11-03T09:30:00-03:00', 'dh_end', '2026-11-03T09:45:00-03:00'));
  -- encostar nao conflita
  perform ad.appointment_save(_base || jsonb_build_object('nr_patient', _pb, 'nr_professional', _ana,
            'dh_start', '2026-11-03T10:00:00-03:00', 'dh_end', '2026-11-03T10:30:00-03:00'));

  -- compromisso da clinica toda bloqueia todo mundo; do profissional, so ele
  _a3 := (ad.appointment_save(_base || jsonb_build_object('it_type', 2, 'vc_title', 'Reunião geral',
           'dh_start', '2026-11-03T12:00:00-03:00', 'dh_end', '2026-11-03T13:00:00-03:00')) ->> 'nr_appointment')::bigint;
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _bia,
            'dh_start', '2026-11-03T12:30:00-03:00', 'dh_end', '2026-11-03T13:30:00-03:00'), 'APPOINTMENT_CONFLICT');
  perform ad.appointment_save(_base || jsonb_build_object('it_type', 2, 'vc_title', 'Curso',
            'nr_professional', _bia, 'id_all_day', true,
            'dh_start', '2026-11-04T00:00:00-03:00', 'dh_end', '2026-11-05T00:00:00-03:00'));
  perform ad.appointment_save(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _ana,
            'dh_start', '2026-11-04T09:00:00-03:00', 'dh_end', '2026-11-04T10:00:00-03:00'));
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pb, 'nr_professional', _bia,
            'dh_start', '2026-11-04T09:00:00-03:00', 'dh_end', '2026-11-04T10:00:00-03:00'), 'APPOINTMENT_CONFLICT');

  -- lista do dia 03/11 (fuso da filial): 5 do dia, alerta de retorno so no periodo
  _r := ad.appointment_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'dt_start', '2026-11-03'));
  assert jsonb_array_length(_r -> 'appointments') = 5, 'agenda do dia 03/11, veio ' || jsonb_array_length(_r -> 'appointments');
  _ap := _r -> 'appointments' -> 0;
  assert _ap ->> 'vc_patient_name' = 'Paciente Um' and _ap ->> 'vc_professional_name' = 'Dra. Ana'
     and _ap ->> 'vc_professional_color' = '#0E8C86' and _ap ->> 'vc_created_by' = 'Kim Agenda', 'dados da consulta';
  assert _r ->> 'vc_timezone' = 'America/Sao_Paulo', 'fuso da filial';
  assert _r -> 'return_alerts' = '[]'::jsonb, 'retorno de 04/11 fora do dia 03/11';

  _r := ad.appointment_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
          'dt_start', '2026-11-02', 'dt_end', '2026-11-08', 'nr_professionals', jsonb_build_array(_bia)));
  assert jsonb_array_length(_r -> 'appointments') = 3, 'semana da Bia: consulta, reuniao geral e curso, veio '
    || jsonb_array_length(_r -> 'appointments');
  assert (_r -> 'return_alerts' -> 0 ->> 'vc_return_alert') = 'Revisão', 'alerta de retorno na semana';

  begin
    perform ad.appointment_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
              'dt_start', '2026-11-10', 'dt_end', '2026-11-01'));
    raise exception 'FALHA: periodo invertido aceito';
  exception when others then
    if sqlerrm not like '%APPOINTMENT_LIST_PERIOD_INVALID%' then raise; end if;
  end;
  begin
    perform ad.appointment_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
              'dt_start', '2026-01-01', 'dt_end', '2026-12-31'));
    raise exception 'FALHA: periodo longo aceito';
  exception when others then
    if sqlerrm not like '%APPOINTMENT_LIST_PERIOD_INVALID%' then raise; end if;
  end;

  -- situacao e update parcial; cancelada libera o horario e some da lista
  perform ad.appointment_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_appointment', _a1, 'it_status', 2));
  assert (select it_status = 2 and vc_notes = 'Primeira consulta' and nr_patient = _pa
            from od.appointment where nr_company = _ca and nr_appointment = _a1), 'so a situacao mudou';
  perform ad.appointment_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_appointment', _a1, 'vc_notes', null));
  assert (select vc_notes is null from od.appointment where nr_company = _ca and nr_appointment = _a1), 'null limpa';
  perform ad.appointment_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_appointment', _a2, 'it_status', 90));
  _r := ad.appointment_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
          'dt_start', '2026-11-03', 'nr_professionals', jsonb_build_array(_bia)));
  assert jsonb_array_length(_r -> 'appointments') = 1, 'cancelada some (fica a reuniao geral)';
  _r := ad.appointment_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1,
          'dt_start', '2026-11-03', 'nr_professionals', jsonb_build_array(_bia), 'id_include_cancelled', true));
  assert jsonb_array_length(_r -> 'appointments') = 2, 'id_include_cancelled traz a cancelada';
  perform ad.appointment_save(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _bia,
            'dh_start', '2026-11-03T09:30:00-03:00', 'dh_end', '2026-11-03T10:30:00-03:00'));
  perform pg_temp.expect_error(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_appointment', 99, 'it_status', 2), 'APPOINTMENT_NOT_FOUND');

  -- profissional inativado: a consulta dele continua editavel; consulta nova nao
  perform ad.professional_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_professional', _ana, 'it_status', 90));
  perform ad.appointment_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
            'nr_appointment', _a1, 'it_status', 5));
  perform pg_temp.expect_error(_base || jsonb_build_object('nr_patient', _pa, 'nr_professional', _ana,
            'dh_start', '2026-11-05T09:00:00-03:00', 'dh_end', '2026-11-05T10:00:00-03:00'), 'APPOINTMENT_PROFESSIONAL_INVALID');

  -- log sem dados pessoais
  assert not exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'appointment'
                       and (e.vc_summary ilike '%Paciente%' or e.js_detail::text ilike '%Paciente%')),
    'event_log sem nome de paciente';
  assert (select vc_summary from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'appointment'
           order by e.dh_created, e.nr_event limit 1) = 'Consulta 03/11/2026 09:00 agendado(a)', 'resumo no fuso da filial';

  -- perfil Recepcao (AGENDA ler + criar) para a Lia
  _r := ad.access_profile_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
          'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', _uu, 'id_read', true, 'id_create', true))));
  _prof := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'vc_email', 'lia.ag@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _prof))));
end $$;

-- ----------------------------------------------------------------------------
\echo '== Lia (Recepcao): agenda e cria, nao altera'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000082","role":"authenticated"}', true);
set local role authenticated;

do $$
declare
  _ca bigint := current_setting('test.nr_company')::bigint;
  _r  jsonb;
begin
  _r := ad.appointment_list(jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1, 'dt_start', '2026-11-03'));
  assert jsonb_array_length(_r -> 'appointments') = 5, 'Lia le a agenda';
  perform ad.appointment_save(jsonb_build_object('nr_version', 1, 'vc_action', 'I', 'nr_company', _ca, 'nr_branch', 1,
            'it_type', 2, 'vc_title', 'Almoço', 'nr_professional', 2,
            'dh_start', '2026-11-06T12:00:00-03:00', 'dh_end', '2026-11-06T13:00:00-03:00'));
  begin
    perform ad.appointment_save(jsonb_build_object('nr_version', 1, 'vc_action', 'U', 'nr_company', _ca, 'nr_branch', 1,
              'nr_appointment', 1, 'it_status', 7));
    raise exception 'FALHA: Lia alterou a situacao';
  exception when others then
    if sqlerrm not like '%APPOINTMENT_FORBIDDEN%' then raise; end if;
  end;
  assert (select count(*) from od.appointment) = 9, 'RLS: Lia ve os agendamentos da filial, veio ' || (select count(*) from od.appointment);
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.appointment_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou appointment_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 11_appointments'
