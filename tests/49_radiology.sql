-- ============================================================================
-- Exames de imagem: centros radiologicos e pedidos de exame
-- (ad.radiology_center_save, ad.radiology_save, ad.radiology_list).
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/49_radiology.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f3', 'ivo.rx@test.local', '{"name": "Ivo Raio"}'),
  ('00000000-0000-0000-0000-0000000000f4', 'olga.rx@test.local', '{"name": "Olga Outra"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f3","role":"authenticated"}', true);
set local role authenticated;

\echo '== Ivo: centros radiologicos'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _c1   bigint;
  _c2   bigint;
  _pa   bigint;
  _pr   bigint;
  _r    jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Raio"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);

  perform pg_temp.expect_error('radiology_center_save', _base || '{"vc_action": "X"}'::jsonb, 'RADIOLOGY_ACTION_INVALID');
  perform pg_temp.expect_error('radiology_center_save', _base || '{"vc_action": "I", "vc_name": " "}'::jsonb,
                               'RADIOLOGY_CENTER_NAME_REQUIRED');
  perform pg_temp.expect_error('radiology_center_save', _base || '{"vc_action": "I", "vc_name": "X", "vc_phone": "123"}'::jsonb,
                               'RADIOLOGY_CENTER_PHONE_INVALID');
  perform pg_temp.expect_error('radiology_center_save', _base || '{"vc_action": "I", "vc_name": "X", "vc_email": "a@"}'::jsonb,
                               'RADIOLOGY_CENTER_EMAIL_INVALID');
  perform pg_temp.expect_error('radiology_center_save', _base || '{"vc_action": "I", "vc_name": "X", "it_integration": 2}'::jsonb,
                               'RADIOLOGY_VALUE_INVALID');

  _c1 := (ad.radiology_center_save(_base || '{"vc_action": "I", "vc_name": "Radio Imagem", "vc_phone": "(41) 3333-4444",
            "vc_email": "Contato@RadioImagem.local", "vc_external_code": "CLI-77"}'::jsonb) ->> 'nr_center')::bigint;
  _c2 := (ad.radiology_center_save(_base || '{"vc_action": "I", "vc_name": "Centro Dois"}'::jsonb) ->> 'nr_center')::bigint;
  assert _c1 = 1 and _c2 = 2, 'sequencial';
  perform pg_temp.expect_error('radiology_center_save', _base || '{"vc_action": "I", "vc_name": "radio imagem"}'::jsonb,
                               'RADIOLOGY_CENTER_NAME_EXISTS');
  assert (select vc_phone || ' ' || vc_email from od.radiology_center where nr_company = _ca and nr_center = _c1)
         = '4133334444 contato@radioimagem.local', 'normalizado';
  -- update parcial: inativa o centro dois e nao mexe no nome
  perform ad.radiology_center_save(_base || jsonb_build_object('vc_action', 'U', 'nr_center', _c2, 'it_status', 90));
  assert (select vc_name from od.radiology_center where nr_company = _ca and nr_center = _c2) = 'Centro Dois', 'parcial';
  perform pg_temp.expect_error('radiology_center_save', _base || '{"vc_action": "U", "nr_center": 99, "vc_name": "Z"}'::jsonb,
                               'RADIOLOGY_CENTER_NOT_FOUND');

  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Rui Raio", "dt_birth": "1980-05-05",
           "vc_cpf": "52998224725", "vc_mobile": "41999990000"}'::jsonb) ->> 'nr_patient')::bigint;
  _pr := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dr. Rx"}'::jsonb) ->> 'nr_professional')::bigint;
  perform set_config('test.pa', _pa::text, false);
  perform set_config('test.pr', _pr::text, false);
  perform set_config('test.c1', _c1::text, false);
  perform set_config('test.c2', _c2::text, false);
end $$;

\echo '== Ivo: pedidos de exame'
do $$
declare
  _ca   bigint := current_setting('test.c')::bigint;
  _pa   bigint := current_setting('test.pa')::bigint;
  _pr   bigint := current_setting('test.pr')::bigint;
  _c1   bigint := current_setting('test.c1')::bigint;
  _c2   bigint := current_setting('test.c2')::bigint;
  _base jsonb;
  _n    bigint;
  _rq   od.radiology_request;
  _r    jsonb;
begin
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);

  perform pg_temp.expect_error('radiology_save', _base || '{"vc_action": "I", "nr_patient": 999, "ar_exams": ["Panorâmica"]}'::jsonb,
                               'RADIOLOGY_PATIENT_INVALID');
  perform pg_temp.expect_error('radiology_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
                               'ar_exams', '[" "]'::jsonb), 'RADIOLOGY_EXAMS_REQUIRED');
  perform pg_temp.expect_error('radiology_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa),
                               'RADIOLOGY_EXAMS_REQUIRED');
  perform pg_temp.expect_error('radiology_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
                               'ar_exams', '["Panorâmica"]'::jsonb, 'nr_center', _c2), 'RADIOLOGY_CENTER_INVALID');
  perform pg_temp.expect_error('radiology_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
                               'ar_exams', '["Panorâmica"]'::jsonb, 'vc_report_url', 'http://x'), 'RADIOLOGY_URL_INVALID');
  perform pg_temp.expect_error('radiology_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
                               'ar_exams', '["Panorâmica"]'::jsonb, 'it_status', 7), 'RADIOLOGY_STATUS_INVALID');
  perform pg_temp.expect_error('radiology_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
                               'ar_exams', '"Panorâmica"'::jsonb), 'RADIOLOGY_VALUE_INVALID');

  _n := (ad.radiology_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_center', _c1,
          'nr_professional', _pr, 'ar_exams', '["Panorâmica", " Tomografia Cone Beam ", ""]'::jsonb,
          'vc_region', '36, 37', 'vc_notes', 'Avaliar canal')) ->> 'nr_request')::bigint;
  select * into _rq from od.radiology_request where nr_company = _ca and nr_request = _n;
  assert _rq.it_status = 1 and _rq.ar_exams = array['Panorâmica', 'Tomografia Cone Beam'] and _rq.dt_request is not null,
    'pedido: ' || row_to_json(_rq)::text;

  -- agendado e depois laudo recebido (preenche realizado e laudo)
  perform ad.radiology_save(_base || jsonb_build_object('vc_action', 'U', 'nr_request', _n, 'it_status', 2,
            'dt_scheduled', _rq.dt_request + 2));
  _r := ad.radiology_save(_base || jsonb_build_object('vc_action', 'U', 'nr_request', _n, 'it_status', 4,
          'vc_report_url', 'https://portal.radio.local/laudo/123'));
  select * into _rq from od.radiology_request where nr_company = _ca and nr_request = _n;
  assert _rq.it_status = 4 and _rq.dt_done is not null and _rq.dt_report is not null
     and _rq.dt_scheduled = _rq.dt_request + 2 and _rq.vc_region = '36, 37', 'laudo: ' || row_to_json(_rq)::text;
  perform pg_temp.expect_error('radiology_save', _base || jsonb_build_object('vc_action', 'U', 'nr_request', _n,
                               'dt_done', _rq.dt_request - 1), 'RADIOLOGY_VALUE_INVALID');

  -- o centro inativado continua aceito no pedido que ja era dele
  perform ad.radiology_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'ar_exams', '["Periapical"]'::jsonb));
  perform ad.radiology_save(_base || jsonb_build_object('vc_action', 'U', 'nr_request', 2, 'it_status', 90));
  perform pg_temp.expect_error('radiology_save', _base || '{"vc_action": "U", "nr_request": 2, "it_status": 1}'::jsonb,
                               'RADIOLOGY_CLOSED');
  perform pg_temp.expect_error('radiology_save', _base || '{"vc_action": "U", "nr_request": 77, "it_status": 1}'::jsonb,
                               'RADIOLOGY_NOT_FOUND');

  _r := ad.radiology_list(_base);
  assert jsonb_array_length(_r -> 'requests') = 1, 'sem os cancelados: ' || _r::text;
  assert _r -> 'requests' -> 0 ->> 'vc_center' = 'Radio Imagem'
     and _r -> 'requests' -> 0 ->> 'vc_professional' = 'Dr. Rx'
     and _r -> 'requests' -> 0 -> 'ar_exams' ->> 1 = 'Tomografia Cone Beam', 'linha: ' || (_r -> 'requests' -> 0)::text;
  assert (_r -> 'totals' ->> 'qt_report')::int = 1 and (_r -> 'totals' ->> 'qt_requested')::int = 0, 'totais';
  assert jsonb_array_length(_r -> 'centers') = 2 and _r -> 'centers' -> 0 ->> 'vc_name' = 'Radio Imagem', 'centros';
  assert jsonb_array_length(ad.radiology_list(_base || '{"it_status": 90}'::jsonb) -> 'requests') = 1, 'cancelados';
  assert jsonb_array_length(ad.radiology_list(_base || '{"vc_search": "tomog"}'::jsonb) -> 'requests') = 1, 'busca exame';
  assert jsonb_array_length(ad.radiology_list(_base || '{"vc_search": "nada"}'::jsonb) -> 'requests') = 0, 'busca vazia';
  perform pg_temp.expect_error('radiology_list', _base || '{"dt_start": "x"}'::jsonb, 'RADIOLOGY_VALUE_INVALID');

  assert (select count(*) from ad.event_log e where e.nr_company = _ca and e.vc_entity like 'radiology%') >= 5, 'event_log';
end $$;

\echo '== Olga (outra empresa) nao ve nem grava'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f4","role":"authenticated"}', true);
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
begin
  perform pg_temp.expect_error('radiology_list', _base, 'RADIOLOGY_FORBIDDEN');
  perform pg_temp.expect_error('radiology_center_save', _base || '{"vc_action": "I", "vc_name": "Invasor"}'::jsonb,
                               'RADIOLOGY_FORBIDDEN');
  perform pg_temp.expect_error('radiology_save', _base || '{"vc_action": "U", "nr_request": 1, "it_status": 1}'::jsonb,
                               'RADIOLOGY_FORBIDDEN');
  assert (select count(*) from od.radiology_request) = 0, 'RLS esconde os pedidos';
  assert (select count(*) from od.radiology_center) = 0, 'RLS esconde os centros';
end $$;

rollback;
\o
\echo 'OK: 49_radiology'
