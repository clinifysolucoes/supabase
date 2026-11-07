-- ============================================================================
-- Agendamento online: configuracao (SETTINGS) e a RPC publica
-- ad.online_booking_public (so service_role): INFO, SLOTS e BOOK.
--   Ivo = administrador da empresa
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/29_online_booking.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', 'ivo.onl@test.local', '{"name": "Ivo Onl"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Ivo: configura'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _prof  bigint;
  _off   bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clínica Sorriso Online"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Rosa", "qt_slot_minutes": 60,
            "schedules": [{"it_weekday": 0, "qt_minute_start": 480, "qt_minute_end": 720},
                          {"it_weekday": 1, "qt_minute_start": 480, "qt_minute_end": 720},
                          {"it_weekday": 2, "qt_minute_start": 480, "qt_minute_end": 720},
                          {"it_weekday": 3, "qt_minute_start": 480, "qt_minute_end": 720},
                          {"it_weekday": 4, "qt_minute_start": 480, "qt_minute_end": 720},
                          {"it_weekday": 5, "qt_minute_start": 480, "qt_minute_end": 720},
                          {"it_weekday": 6, "qt_minute_start": 480, "qt_minute_end": 720}]}'::jsonb) ->> 'nr_professional')::bigint;
  _off := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dr. Fora"}'::jsonb) ->> 'nr_professional')::bigint;
  perform set_config('test.nr_professional', _prof::text, false);
  perform set_config('test.nr_off', _off::text, false);

  _r := ad.online_booking_settings_get(_base);
  assert not (_r -> 'settings' ->> 'id_enabled')::boolean and not (_r -> 'settings' ->> 'id_saved')::boolean, 'padrao desligado';
  assert _r -> 'settings' ->> 'vc_slug' ~ '^[a-z0-9-]+$', 'slug sugerido: ' || (_r -> 'settings' ->> 'vc_slug');

  perform pg_temp.expect_error('online_booking_settings_save', _base || '{"id_enabled": true, "vc_slug": "sorriso-teste"}'::jsonb,
            'ONLINE_BOOKING_NO_PROFESSIONAL');
  perform pg_temp.expect_error('online_booking_settings_save', _base || '{"vc_slug": "x"}'::jsonb, 'ONLINE_BOOKING_SLUG_INVALID');
  perform pg_temp.expect_error('online_booking_settings_save', _base || '{"qt_days_ahead": 0}'::jsonb, 'ONLINE_BOOKING_VALUE_INVALID');
  perform pg_temp.expect_error('online_booking_settings_save', _base || '{"professionals": [{"nr_professional": 999, "id_online": true}]}'::jsonb,
            'ONLINE_BOOKING_PROFESSIONAL_INVALID');
  _r := ad.online_booking_settings_save(_base || jsonb_build_object('id_enabled', true, 'vc_slug', ' Sorriso Teste!! ',
          'qt_days_ahead', 10, 'qt_min_hours', 0, 'vc_message', 'Chegue 10 minutos antes.',
          'professionals', jsonb_build_array(jsonb_build_object('nr_professional', _prof, 'id_online', true))));
  assert _r ->> 'vc_slug' = 'sorriso-teste' and (_r ->> 'id_enabled')::boolean, 'ligado com slug normalizado';
  _r := ad.online_booking_settings_get(_base);
  assert (_r -> 'settings' ->> 'id_saved')::boolean and (_r -> 'settings' ->> 'qt_days_ahead')::int = 10, 'gravado';
  assert (select count(*) from jsonb_array_elements(_r -> 'professionals') p where (p ->> 'id_online')::boolean) = 1, 'um online';
end $$;

\echo '== authenticated nao chama a RPC publica'
do $$
begin
  begin
    perform ad.online_booking_public('{"nr_version": 1, "vc_action": "INFO", "vc_slug": "sorriso-teste"}'::jsonb);
    raise exception 'FALHA: authenticated chamou online_booking_public';
  exception when insufficient_privilege then null;
  end;
end $$;

\echo '== service_role: INFO, SLOTS, BOOK'
reset role;
set local role service_role;
do $$
declare
  _r     jsonb;
  _ca    bigint := current_setting('test.nr_company')::bigint;
  _prof  bigint := current_setting('test.nr_professional')::bigint;
  _day   date;
  _slot  text;
  _book  jsonb;
  _base  jsonb := '{"nr_version": 1, "vc_slug": "sorriso-teste"}'::jsonb;
begin
  perform pg_temp.expect_error('online_booking_public', '{"nr_version": 1, "vc_action": "INFO", "vc_slug": "nao-existe"}'::jsonb,
            'ONLINE_BOOKING_NOT_FOUND');
  _r := ad.online_booking_public(_base || '{"vc_action": "INFO"}'::jsonb);
  assert jsonb_array_length(_r -> 'professionals') = 1 and _r ->> 'vc_message' = 'Chegue 10 minutos antes.', 'info';
  assert _r -> 'clinic' ->> 'vc_name' is not null and not (_r::text like '%Dr. Fora%'), 'so os marcados';

  perform pg_temp.expect_error('online_booking_public', _base || jsonb_build_object('vc_action', 'SLOTS',
            'nr_professional', current_setting('test.nr_off')::bigint, 'dt_day', current_date + 1), 'ONLINE_BOOKING_PROFESSIONAL_INVALID');
  perform pg_temp.expect_error('online_booking_public', _base || jsonb_build_object('vc_action', 'SLOTS',
            'nr_professional', _prof, 'dt_day', current_date + 30), 'ONLINE_BOOKING_DATE_INVALID');

  _day := current_date + 2;
  _r := ad.online_booking_public(_base || jsonb_build_object('vc_action', 'SLOTS', 'nr_professional', _prof, 'dt_day', _day));
  assert _r -> 'slots' = '["08:00", "09:00", "10:00", "11:00"]'::jsonb, 'quatro horarios de 1 h: ' || (_r -> 'slots')::text;

  -- compromisso da clinica das 9 as 10 tira o horario das 9
  insert into od.appointment (nr_company, nr_branch, nr_appointment, it_type, vc_title, dh_start, dh_end)
  values (_ca, 1, 900, 2, 'Reunião',
          (_day + time '09:00') at time zone 'America/Sao_Paulo', (_day + time '10:00') at time zone 'America/Sao_Paulo');
  _r := ad.online_booking_public(_base || jsonb_build_object('vc_action', 'SLOTS', 'nr_professional', _prof, 'dt_day', _day));
  assert _r -> 'slots' = '["08:00", "10:00", "11:00"]'::jsonb, 'sem as 9';

  _book := _base || jsonb_build_object('vc_action', 'BOOK', 'nr_professional', _prof, 'dh_start', _day::text || ' 10:00',
             'vc_name', '  Paula   Online ', 'vc_cpf', '529.982.247-25', 'dt_birth', '1990-04-01', 'vc_mobile', '(41) 99999-1234',
             'vc_email', 'Paula@Exemplo.com', 'vc_notes', 'Dor no dente');
  perform pg_temp.expect_error('online_booking_public', _book || '{"vc_cpf": "111.111.111-11"}'::jsonb, 'ONLINE_BOOKING_CPF_INVALID');
  perform pg_temp.expect_error('online_booking_public', _book || '{"vc_mobile": "123"}'::jsonb, 'ONLINE_BOOKING_MOBILE_INVALID');
  perform pg_temp.expect_error('online_booking_public', _book || '{"dt_birth": "2999-01-01"}'::jsonb, 'ONLINE_BOOKING_BIRTH_INVALID');
  perform pg_temp.expect_error('online_booking_public', _book || jsonb_build_object('dh_start', _day::text || ' 09:00'),
            'ONLINE_BOOKING_SLOT_TAKEN');
  perform pg_temp.expect_error('online_booking_public', _book || jsonb_build_object('dh_start', _day::text || ' 10:30'),
            'ONLINE_BOOKING_SLOT_TAKEN');

  _r := ad.online_booking_public(_book);
  assert _r ->> 'dh_start' = _day::text || ' 10:00' and _r ->> 'vc_professional' = 'Dra. Rosa', 'marcado';
  assert (select count(*) from od.patient p where p.nr_company = _ca and p.vc_cpf = '52998224725'
            and p.vc_name = 'Paula Online' and p.vc_mobile = '41999991234' and p.vc_email = 'paula@exemplo.com') = 1, 'ficha criada';
  assert (select a.it_origin = 2 and a.it_status = 1 and a.vc_notes like '%Dor no dente%' from od.appointment a
           where a.nr_company = _ca and a.nr_appointment = (_r ->> 'nr_appointment')::bigint), 'consulta online agendada';
  perform pg_temp.expect_error('online_booking_public', _book, 'ONLINE_BOOKING_SLOT_TAKEN');   -- horario ocupado agora

  -- mesmo CPF: usa a ficha existente; terceira consulta online passa do limite
  perform ad.online_booking_public(_book || jsonb_build_object('dh_start', _day::text || ' 11:00', 'vc_name', 'Outro Nome'));
  assert (select count(*) from od.patient p where p.nr_company = _ca and p.vc_cpf = '52998224725') = 1, 'ficha reaproveitada';
  perform pg_temp.expect_error('online_booking_public', _book || jsonb_build_object('dh_start', _day::text || ' 08:00'),
            'ONLINE_BOOKING_LIMIT');
end $$;

\echo '== desligado some'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  _r := ad.appointment_list(_base || jsonb_build_object('dt_start', current_date, 'dt_end', current_date + 5));
  assert (select count(*) from jsonb_array_elements(_r -> 'appointments') a where (a ->> 'it_origin')::int = 2) = 2,
    'agenda mostra a origem';
  perform ad.online_booking_settings_save(_base || '{"id_enabled": false}'::jsonb);
end $$;
reset role;
set local role service_role;
do $$
begin
  perform pg_temp.expect_error('online_booking_public', '{"nr_version": 1, "vc_action": "INFO", "vc_slug": "sorriso-teste"}'::jsonb,
            'ONLINE_BOOKING_NOT_FOUND');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.online_booking_public('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou online_booking_public';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 29_online_booking'
