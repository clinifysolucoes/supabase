-- ============================================================================
-- Configuracoes, parte A: ad.settings_get / ad.settings_save, dados da clinica
-- em ad.branch_update e as regras que entram na agenda (ad.appointment_save) e
-- no cadastro de pacientes (ad.patient_save).
--   Mel = administradora da empresa
--   Oto = usuario sem empresa
-- Datas fixas (segunda-feira 2030-03-04); termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/18_settings.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', 'mel.cfg@test.local', '{"name": "Mel Config"}'),
  ('00000000-0000-0000-0000-0000000000f3', 'oto.cfg@test.local', '{"name": "Oto Config"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Mel: configuracoes'
do $$
declare
  _r    jsonb;
  _ca   bigint;
  _base jsonb;
  _ana  bigint;
  _pa   bigint;
  _ap   jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Config"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);

  -- padroes sem linha
  _r := ad.settings_get(_base);
  assert (_r -> 'settings' ->> 'qt_slot_minutes')::int = 15 and (_r -> 'settings' ->> 'qt_max_parallel')::int = 1
     and (_r -> 'settings' ->> 'id_allow_outside_hours')::boolean, 'padroes';
  assert (_r -> 'permission' ->> 'id_update')::boolean and (_r -> 'permission' ->> 'id_clinic')::boolean, 'admin altera';

  -- validacoes
  perform pg_temp.expect_error('settings_save', _base || '{"qt_slot_minutes": 10}'::jsonb, 'SETTINGS_SLOT_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"qt_max_parallel": 0}'::jsonb, 'SETTINGS_PARALLEL_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"nr_next_record": 0}'::jsonb, 'SETTINGS_RECORD_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"hours": [{"it_weekday": 1, "qt_minute_start": 480, "qt_minute_end": 720},
            {"it_weekday": 1, "qt_minute_start": 700, "qt_minute_end": 800}]}'::jsonb, 'SETTINGS_HOURS_INVALID');

  _r := ad.settings_save(_base || '{"qt_slot_minutes": 30, "qt_max_parallel": 2, "id_allow_outside_hours": false,
          "id_auto_record_number": true, "nr_next_record": 100, "vc_patient_required": ["rg", "address", "email"],
          "hours": [{"it_weekday": 1, "qt_minute_start": 480, "qt_minute_end": 720},
                    {"it_weekday": 1, "qt_minute_start": 780, "qt_minute_end": 1080}]}'::jsonb);
  assert (_r -> 'settings' ->> 'qt_slot_minutes')::int = 30 and jsonb_array_length(_r -> 'hours') = 2, 'gravou';
  -- parcial: so muda o que veio
  _r := ad.settings_save(_base || '{"qt_slot_minutes": 20}'::jsonb);
  assert (_r -> 'settings' ->> 'qt_max_parallel')::int = 2 and jsonb_array_length(_r -> 'hours') = 2, 'parcial';

  -- dados da clinica
  perform pg_temp.expect_error('branch_update', _base || '{"vc_phone_extra": "123"}'::jsonb, 'BRANCH_UPDATE_PHONE_INVALID');
  perform pg_temp.expect_error('branch_update', _base || '{"vc_technical_cro_state": "P1"}'::jsonb, 'BRANCH_UPDATE_STATE_INVALID');
  perform ad.branch_update(_base || '{"vc_phone_extra": "(41) 3333-4444", "vc_technical_name": "Dra. Mel",
            "vc_technical_cro": "12345", "vc_technical_cro_state": "pr", "vc_forum_city": "Curitiba"}'::jsonb);
  _r := ad.settings_get(_base);
  assert (_r -> 'clinic' ->> 'vc_phone_extra') = '4133334444' and (_r -> 'clinic' ->> 'vc_technical_cro_state') = 'PR'
     and (_r -> 'clinic' ->> 'vc_forum_city') = 'Curitiba', 'dados da clinica';

  -- obrigatorios da filial: lista validada e sem repeticao
  perform pg_temp.expect_error('settings_save', _base || '{"vc_patient_required": ["rg", "cpf"]}'::jsonb, 'SETTINGS_VALUE_INVALID');
  perform pg_temp.expect_error('settings_save', _base || '{"vc_patient_required": "rg"}'::jsonb, 'SETTINGS_VALUE_INVALID');
  assert (ad.settings_get(_base) -> 'settings' -> 'vc_patient_required') = '["address", "email", "rg"]'::jsonb, 'obrigatorios gravados';

  -- paciente: CPF sempre obrigatorio, obrigatorios da filial e prontuario automatico
  perform pg_temp.expect_error('patient_save', _base || '{"vc_action": "I", "vc_name": "Sem CPF", "dt_birth": "1990-01-01"}'::jsonb,
            'PATIENT_CPF_REQUIRED');
  perform pg_temp.expect_error('patient_save', _base || '{"vc_action": "I", "vc_name": "Sem RG", "dt_birth": "1990-01-01",
            "vc_cpf": "529.982.247-25", "vc_zip": "80000000", "vc_address": "Rua A", "vc_address_number": "1",
            "vc_district": "Centro", "vc_city": "Curitiba", "vc_state": "PR", "id_no_email": true}'::jsonb, '"Field": "RG"');
  perform pg_temp.expect_error('patient_save', _base || '{"vc_action": "I", "vc_name": "Sem Bairro", "dt_birth": "1990-01-01",
            "vc_cpf": "529.982.247-25", "vc_rg": "1234", "vc_zip": "80000000", "vc_address": "Rua A", "vc_address_number": "1",
            "vc_city": "Curitiba", "vc_state": "PR", "id_no_email": true}'::jsonb, 'Endereço completo');
  perform pg_temp.expect_error('patient_save', _base || '{"vc_action": "I", "vc_name": "Sem Email", "dt_birth": "1990-01-01",
            "vc_cpf": "529.982.247-25", "vc_rg": "1234", "vc_zip": "80000000", "vc_address": "Rua A", "vc_address_number": "1",
            "vc_district": "Centro", "vc_city": "Curitiba", "vc_state": "PR"}'::jsonb, 'PATIENT_FIELD_REQUIRED');
  perform ad.settings_save(_base || '{"vc_patient_required": []}'::jsonb);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Com CPF", "dt_birth": "1990-01-01",
            "vc_cpf": "529.982.247-25"}'::jsonb) ->> 'nr_patient')::bigint;
  assert (select vc_record_number from od.patient where nr_company = _ca and nr_patient = _pa) = '100', 'prontuario 100';
  assert (ad.settings_get(_base) -> 'settings' ->> 'nr_next_record')::int = 101, 'proximo 101';

  -- agenda: profissional atende segunda 8-12 e 13-18
  _ana := (ad.professional_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Dra. Ana',
           'schedules', jsonb_build_array(jsonb_build_object('it_weekday', 1, 'qt_minute_start', 480, 'qt_minute_end', 720),
                                          jsonb_build_object('it_weekday', 1, 'qt_minute_start', 780, 'qt_minute_end', 1080))))
           ->> 'nr_professional')::bigint;
  _ap := _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _ana);
  -- fora do horario (12h-13h e domingo)
  perform pg_temp.expect_error('appointment_save', _ap || '{"dh_start": "2030-03-04T12:00:00-03:00", "dh_end": "2030-03-04T12:30:00-03:00"}'::jsonb,
            'APPOINTMENT_OUTSIDE_HOURS');
  perform pg_temp.expect_error('appointment_save', _ap || '{"dh_start": "2030-03-03T09:00:00-03:00", "dh_end": "2030-03-03T09:30:00-03:00"}'::jsonb,
            'APPOINTMENT_OUTSIDE_HOURS');
  -- encaixe passa
  perform ad.appointment_save(_ap || '{"dh_start": "2030-03-04T12:00:00-03:00", "dh_end": "2030-03-04T12:30:00-03:00", "id_fit_in": true}'::jsonb);
  -- duas no mesmo horario (limite 2), a terceira conflita
  perform ad.appointment_save(_ap || '{"dh_start": "2030-03-04T09:00:00-03:00", "dh_end": "2030-03-04T10:00:00-03:00"}'::jsonb);
  perform ad.appointment_save(_ap || '{"dh_start": "2030-03-04T09:30:00-03:00", "dh_end": "2030-03-04T10:00:00-03:00"}'::jsonb);
  perform pg_temp.expect_error('appointment_save', _ap || '{"dh_start": "2030-03-04T09:00:00-03:00", "dh_end": "2030-03-04T09:30:00-03:00"}'::jsonb,
            'APPOINTMENT_CONFLICT');
  -- permitindo fora do horario, o domingo passa
  perform ad.settings_save(_base || '{"id_allow_outside_hours": true}'::jsonb);
  perform ad.appointment_save(_ap || '{"dh_start": "2030-03-03T09:00:00-03:00", "dh_end": "2030-03-03T09:30:00-03:00"}'::jsonb);
end $$;

\echo '== Oto (sem empresa) e anon: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f3","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('settings_get', _base, 'SETTINGS_FORBIDDEN');
  perform pg_temp.expect_error('settings_save', _base || '{"qt_slot_minutes": 5}'::jsonb, 'SETTINGS_FORBIDDEN');
  assert (select count(*) from od.branch_setting) = 0, 'RLS: Oto nao ve configuracoes';
  assert (select count(*) from od.branch_hour) = 0, 'RLS: Oto nao ve horarios';
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.settings_get('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou settings_get';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 18_settings'
