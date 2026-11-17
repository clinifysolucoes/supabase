-- ============================================================================
-- Agenda: categorias, marcadores e cadeiras (ad.agenda_catalog_save,
-- ad.appointment_save, ad.appointment_list, ad.settings_*) e os relatorios
-- por categoria e por marcador.
--   Eli = administradora da empresa
--   Bia = recepcao (agenda: ler e criar; configuracoes: nao)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/41_agenda_tags.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', 'eli.tag@test.local', '{"name": "Eli Tag"}'),
  ('00000000-0000-0000-0000-0000000000e2', 'bia.tag@test.local', '{"name": "Bia Tag"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Eli: cadastros, consultas e relatorios'
do $$
declare
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _p1    bigint;
  _p2    bigint;
  _a1    bigint;
  _r     jsonb;
  _ap    jsonb;
  _pr    bigint;
  _day   jsonb := '{"dh_start": "2030-05-06T10:00:00-03:00", "dh_end": "2030-05-06T10:30:00-03:00"}'::jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Tag"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Tag", "dt_birth": "1990-01-01",
           "vc_cpf": "52998224725", "vc_mobile": "41999990001"}'::jsonb) ->> 'nr_patient')::bigint;
  _p1 := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dr. Um"}'::jsonb) ->> 'nr_professional')::bigint;
  _p2 := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Dois"}'::jsonb) ->> 'nr_professional')::bigint;

  -- cadastros
  _r := ad.agenda_catalog_save(_base || '{"vc_action": "I", "vc_entity": "category", "vc_name": "Avaliação", "vc_color": "#ff0000"}'::jsonb);
  assert (_r ->> 'nr_item')::int = 1, 'categoria 1';
  perform ad.agenda_catalog_save(_base || '{"vc_action": "I", "vc_entity": "category", "vc_name": "Urgência"}'::jsonb);
  perform ad.agenda_catalog_save(_base || '{"vc_action": "I", "vc_entity": "marker", "vc_name": "VIP", "vc_color": "#AA00AA"}'::jsonb);
  perform ad.agenda_catalog_save(_base || '{"vc_action": "I", "vc_entity": "marker", "vc_name": "Primeira vez"}'::jsonb);
  perform ad.agenda_catalog_save(_base || '{"vc_action": "I", "vc_entity": "chair", "vc_name": "Cadeira 1"}'::jsonb);
  perform ad.agenda_catalog_save(_base || '{"vc_action": "I", "vc_entity": "chair", "vc_name": "Cadeira 2"}'::jsonb);
  perform pg_temp.expect_error('agenda_catalog_save', _base || '{"vc_action": "I", "vc_entity": "chair", "vc_name": "cadeira 1"}'::jsonb,
            'AGENDA_CATALOG_NAME_IN_USE');
  perform pg_temp.expect_error('agenda_catalog_save', _base || '{"vc_action": "I", "vc_entity": "marker", "vc_name": "X", "vc_color": "azul"}'::jsonb,
            'AGENDA_CATALOG_COLOR_INVALID');
  perform pg_temp.expect_error('agenda_catalog_save', _base || '{"vc_action": "I", "vc_entity": "sala", "vc_name": "X"}'::jsonb,
            'AGENDA_CATALOG_INVALID');
  perform pg_temp.expect_error('agenda_catalog_save', _base || '{"vc_action": "U", "vc_entity": "chair", "nr_item": 99, "vc_name": "X"}'::jsonb,
            'AGENDA_CATALOG_NOT_FOUND');

  -- preferencias
  _r := ad.settings_save(_base || '{"id_color_by_category": true, "it_agenda_mode": 2}'::jsonb);
  assert (_r -> 'settings' ->> 'id_color_by_category')::boolean and (_r -> 'settings' ->> 'it_agenda_mode')::int = 2, 'preferencias';
  assert jsonb_array_length(_r -> 'agenda_catalog' -> 'categories') = 2 and jsonb_array_length(_r -> 'agenda_catalog' -> 'chairs') = 2
     and _r -> 'agenda_catalog' -> 'categories' -> 0 ->> 'vc_color' = '#FF0000', 'catalogo nas configuracoes';
  perform pg_temp.expect_error('settings_save', _base || '{"it_agenda_mode": 3}'::jsonb, 'SETTINGS_VALUE_INVALID');

  -- consulta com categoria, cadeira e marcadores
  _a1 := (ad.appointment_save(_base || _day || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _p1,
           'nr_category', 1, 'nr_chair', 1, 'nr_markers', jsonb_build_array(1, 2))) ->> 'nr_appointment')::bigint;
  -- outra profissional na mesma cadeira e horario: conflito; outra cadeira ou encaixe: ok
  perform pg_temp.expect_error('appointment_save', _base || _day || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'nr_professional', _p2, 'nr_chair', 1), 'APPOINTMENT_CHAIR_CONFLICT');
  perform ad.appointment_save(_base || _day || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _p2, 'nr_chair', 2));
  perform ad.appointment_save(_base || '{"dh_start": "2030-05-06T10:00:00-03:00", "dh_end": "2030-05-06T10:15:00-03:00"}'::jsonb
            || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _p2, 'nr_chair', 1, 'id_fit_in', true,
                                  'nr_markers', jsonb_build_array(2)));
  perform pg_temp.expect_error('appointment_save', _base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'nr_chair', 9),
            'APPOINTMENT_CHAIR_INVALID');
  perform pg_temp.expect_error('appointment_save', _base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'nr_markers', '[7]'::jsonb),
            'APPOINTMENT_MARKER_INVALID');

  _r := ad.appointment_list(_base || '{"dt_start": "2030-05-06"}'::jsonb);
  assert (_r ->> 'it_agenda_mode')::int = 2 and (_r ->> 'id_color_by_category')::boolean
     and jsonb_array_length(_r -> 'chairs') = 2 and jsonb_array_length(_r -> 'markers') = 2, 'topo da lista';
  select a into _ap from jsonb_array_elements(_r -> 'appointments') a where (a ->> 'nr_appointment')::bigint = _a1;
  assert _ap ->> 'vc_category' = 'Avaliação' and _ap ->> 'vc_display_color' = '#FF0000' and _ap ->> 'vc_chair' = 'Cadeira 1'
     and jsonb_array_length(_ap -> 'markers') = 2, 'consulta com categoria: ' || _ap::text;
  select a into _ap from jsonb_array_elements(_r -> 'appointments') a where (a ->> 'nr_chair')::int = 2;
  assert _ap ->> 'vc_category' is null and _ap ->> 'vc_display_color' is not null, 'sem categoria usa a cor do profissional';

  -- trocar marcadores; marcador inativo continua onde ja estava, mas nao entra em consulta nova
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'nr_markers', '[2]'::jsonb));
  perform ad.agenda_catalog_save(_base || '{"vc_action": "U", "vc_entity": "marker", "nr_item": 2, "it_status": 90}'::jsonb);
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'nr_markers', '[2]'::jsonb,
            'vc_notes', 'ok'));
  perform ad.agenda_catalog_save(_base || '{"vc_action": "U", "vc_entity": "category", "nr_item": 2, "it_status": 90}'::jsonb);
  perform pg_temp.expect_error('appointment_save', _base || '{"dh_start": "2030-05-07T10:00:00-03:00", "dh_end": "2030-05-07T10:30:00-03:00"}'::jsonb
            || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _p1, 'nr_category', 2), 'APPOINTMENT_CATEGORY_INVALID');
  perform pg_temp.expect_error('appointment_save', _base || '{"dh_start": "2030-05-07T10:00:00-03:00", "dh_end": "2030-05-07T10:30:00-03:00"}'::jsonb
            || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _p1, 'nr_markers', '[2]'::jsonb), 'APPOINTMENT_MARKER_INVALID');
  _r := ad.appointment_list(_base || '{"dt_start": "2030-05-06"}'::jsonb);
  select a into _ap from jsonb_array_elements(_r -> 'appointments') a where (a ->> 'nr_appointment')::bigint = _a1;
  assert jsonb_array_length(_ap -> 'markers') = 1 and _ap -> 'markers' -> 0 ->> 'vc_name' = 'Primeira vez', 'marcadores trocados';

  -- relatorios
  _r := ad.report_get(_base || '{"vc_report": "categories", "dt_start": "2030-05-01", "dt_end": "2030-05-31"}'::jsonb);
  assert (_r -> 'summary' ->> 'qt_appointments')::int = 3 and (_r -> 'summary' ->> 'qt_groups')::int = 1
     and _r -> 'rows' -> 0 ->> 'vc_name' = 'Avaliação' and (_r -> 'rows' -> 1 ->> 'qt_total')::int = 2, 'por categoria: ' || _r::text;
  _r := ad.report_get(_base || '{"vc_report": "markers", "dt_start": "2030-05-01", "dt_end": "2030-05-31"}'::jsonb);
  assert jsonb_array_length(_r -> 'rows') = 1 and (_r -> 'rows' -> 0 ->> 'qt_total')::int = 2, 'por marcador: ' || _r::text;

  -- Bia: agenda sim, configuracoes nao
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000007', 'id_read', true,
                                                          'id_create', true, 'id_update', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'bia.tag@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Bia: sem configuracoes'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('agenda_catalog_save', _base || '{"vc_action": "I", "vc_entity": "marker", "vc_name": "Bia"}'::jsonb,
            'AGENDA_CATALOG_FORBIDDEN');
  assert jsonb_array_length(ad.appointment_list(_base || '{"dt_start": "2030-05-06"}'::jsonb) -> 'categories') = 2, 'Bia le o catalogo';
  assert (select count(*) from od.chair where nr_company = current_setting('test.c')::bigint) = 2, 'RLS deixa ler as cadeiras';
end $$;

reset role;
rollback;
\o
\echo 'OK: 41_agenda_tags'
