-- ============================================================================
-- Fichas por especialidade (ad.chart_model_list/save, ad.patient_chart_save/
-- list) e periograma (ad.perio_exam_save/list).
--   Ivo = administrador da empresa
--   Ema = recepcao (PATIENTS so ler)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/39_specialty_charts.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', 'ivo.chart@test.local', '{"name": "Ivo Chart"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'ema.chart@test.local', '{"name": "Ema Chart"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Ivo: modelos, fichas e periograma'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _prof  bigint;
  _endo  bigint;
  _orto  bigint;
  _mine  bigint;
  _ch    bigint;
  _ex    bigint;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Chart"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Chart", "dt_birth": "1985-02-02",
           "vc_cpf": "52998224725"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dr. Luis"}'::jsonb) ->> 'nr_professional')::bigint;

  -- modelos prontos na primeira chamada, uma vez so
  _r := ad.chart_model_list(_base);
  assert jsonb_array_length(_r -> 'models') = 4, 'quatro modelos: ' || jsonb_array_length(_r -> 'models');
  perform ad.chart_model_list(_base);
  assert (select count(*) from od.chart_model where nr_company = _ca) = 4, 'sem duplicar';
  select (m ->> 'nr_model')::bigint into _endo from jsonb_array_elements(_r -> 'models') m where m ->> 'vc_name' = 'Endodontia';
  select (m ->> 'nr_model')::bigint into _orto from jsonb_array_elements(_r -> 'models') m where m ->> 'vc_name' = 'Ortodontia';
  assert (select (m ->> 'id_per_tooth')::boolean from jsonb_array_elements(_r -> 'models') m where m ->> 'vc_name' = 'Endodontia'),
    'endo por dente';
  assert (select jsonb_array_length(m -> 'fields') from jsonb_array_elements(_r -> 'models') m where m ->> 'vc_name' = 'Implantodontia') = 17,
    'campos do implante';

  -- modelo proprio
  perform pg_temp.expect_error('chart_model_save', _base || '{"vc_action": "I", "vc_name": "ortodontia",
            "fields": [{"vc_label": "X"}]}'::jsonb, 'CHART_MODEL_NAME_IN_USE');
  perform pg_temp.expect_error('chart_model_save', _base || '{"vc_action": "I", "vc_name": "HOF"}'::jsonb,
            'CHART_MODEL_FIELDS_REQUIRED');
  perform pg_temp.expect_error('chart_model_save', _base || '{"vc_action": "I", "vc_name": "HOF",
            "fields": [{"vc_label": "Região", "it_type": 4, "vc_options": "Testa"}]}'::jsonb, 'CHART_FIELD_INVALID');
  _mine := (ad.chart_model_save(_base || '{"vc_action": "I", "vc_name": "HOF", "fields": [
            {"vc_label": "Região", "it_type": 4, "vc_options": ["Testa", "Glabela", "Pés de galinha"], "id_required": true},
            {"vc_label": "Unidades", "it_type": 5, "vc_unit": "U"},
            {"vc_label": "Retorno agendado", "it_type": 3},
            {"vc_label": "Aplicação", "it_type": 6}]}'::jsonb) ->> 'nr_model')::bigint;
  assert (select vc_options from od.chart_field where nr_company = _ca and nr_model = _mine and nr_field = 1)
         = 'Testa|Glabela|Pés de galinha', 'opcoes';

  -- ficha por dente
  perform pg_temp.expect_error('patient_chart_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'nr_model', _endo), 'CHART_TOOTH_REQUIRED');
  perform pg_temp.expect_error('patient_chart_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'nr_model', _endo, 'vc_tooth', '19'), 'CHART_TOOTH_INVALID');
  perform pg_temp.expect_error('patient_chart_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'nr_model', _endo, 'vc_tooth', '36', 'values', '[{"nr_field": 6, "vc_value": "Inventado"}]'::jsonb),
            'CHART_VALUE_INVALID');
  _ch := (ad.patient_chart_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_model', _endo,
            'vc_tooth', '36,37', 'nr_professional', _prof, 'values', '[
              {"nr_field": 2, "vc_value": "Espontânea"},
              {"nr_field": 6, "vc_value": "Pulpite irreversível sintomática"},
              {"nr_field": 10, "vc_value": "MV 21 mm, DV 20,5 mm"},
              {"nr_field": 14, "vc_value": "2026-11-01"}]'::jsonb)) ->> 'nr_chart')::bigint;
  _r := ad.patient_chart_list(_base || jsonb_build_object('nr_patient', _pa));
  assert jsonb_array_length(_r -> 'charts') = 1 and _r -> 'charts' -> 0 ->> 'vc_tooth' = '36, 37'
     and _r -> 'charts' -> 0 ->> 'vc_professional' = 'Dr. Luis'
     and jsonb_array_length(_r -> 'charts' -> 0 -> 'values') = 15, 'ficha: ' || (_r -> 'charts' -> 0)::text;

  -- tipos normalizados e obrigatorio
  perform pg_temp.expect_error('patient_chart_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'nr_model', _mine), 'CHART_FIELD_REQUIRED');
  perform pg_temp.expect_error('patient_chart_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'nr_model', _mine, 'values', '[{"nr_field": 1, "vc_value": "Glabela"}, {"nr_field": 2, "vc_value": "dez"}]'::jsonb),
            'CHART_VALUE_INVALID');
  _ch := (ad.patient_chart_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_model', _mine,
            'values', '[{"nr_field": 1, "vc_value": "Glabela"}, {"nr_field": 2, "vc_value": "12,5"},
                        {"nr_field": 3, "vc_value": "sim"}, {"nr_field": 4, "vc_value": "2026-11-10"}]'::jsonb)) ->> 'nr_chart')::bigint;
  assert (select string_agg(coalesce(vc_value, '-'), '|' order by nr_field) from od.patient_chart_value
           where nr_company = _ca and nr_patient = _pa and nr_chart = _ch) = 'Glabela|12.5|S|2026-11-10', 'normalizado';

  -- alterar o modelo nao muda a ficha preenchida
  perform ad.chart_model_save(_base || jsonb_build_object('vc_action', 'U', 'nr_model', _mine, 'vc_name', 'Harmonização',
            'fields', '[{"vc_label": "Produto", "it_type": 1}]'::jsonb));
  assert (select vc_model from od.patient_chart where nr_company = _ca and nr_patient = _pa and nr_chart = _ch) = 'HOF'
     and (select count(*) from od.patient_chart_value where nr_company = _ca and nr_patient = _pa and nr_chart = _ch) = 4,
    'copia preservada';

  -- alterar e excluir
  perform ad.patient_chart_save(_base || jsonb_build_object('vc_action', 'U', 'nr_patient', _pa, 'nr_chart', _ch,
            'vc_notes', 'Retoque em 15 dias', 'values', '[{"nr_field": 3, "vc_value": "N"}]'::jsonb));
  assert (select vc_value from od.patient_chart_value where nr_company = _ca and nr_patient = _pa and nr_chart = _ch
            and nr_field = 3) = 'N', 'alterada';
  perform ad.patient_chart_save(_base || jsonb_build_object('vc_action', 'D', 'nr_patient', _pa, 'nr_chart', _ch));
  assert jsonb_array_length(ad.patient_chart_list(_base || jsonb_build_object('nr_patient', _pa)) -> 'charts') = 1, 'excluida';
  perform pg_temp.expect_error('patient_chart_save', _base || jsonb_build_object('vc_action', 'U', 'nr_patient', _pa,
            'nr_chart', _ch), 'CHART_NOT_FOUND');
  -- modelo inativo nao aceita ficha nova
  perform ad.chart_model_save(_base || jsonb_build_object('vc_action', 'U', 'nr_model', _orto, 'it_status', 90));
  perform pg_temp.expect_error('patient_chart_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'nr_model', _orto), 'CHART_MODEL_NOT_FOUND');
  assert jsonb_array_length(ad.chart_model_list(_base) -> 'models') = 4, 'inativo fora da lista';

  -- periograma
  perform pg_temp.expect_error('perio_exam_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'teeth', '[{"vc_tooth": "19"}]'::jsonb), 'PERIO_TOOTH_INVALID');
  perform pg_temp.expect_error('perio_exam_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'teeth', '[{"vc_tooth": "16", "qt_probing": [3, 2, 16, 3, 2, 3]}]'::jsonb), 'PERIO_TOOTH_INVALID');
  perform pg_temp.expect_error('perio_exam_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'teeth', '[{"vc_tooth": "16", "qt_probing": [3, 2, 3]}]'::jsonb), 'PERIO_TOOTH_INVALID');
  _ex := (ad.perio_exam_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _prof,
            'teeth', '[
              {"vc_tooth": "16", "it_mobility": 1, "it_furcation": 2, "qt_probing": [3, 2, 6, 4, 2, 3],
               "qt_recession": [1, 0, 1, 0, 0, null], "id_bleeding": [true, false, true, false, false, false],
               "id_plaque": [true, true, false, false, false, false]},
              {"vc_tooth": "11", "qt_probing": [2, 2, 2, 2, 2, 2], "qt_recession": [0, 0, 0, 0, 0, 0],
               "id_bleeding": [false, false, false, false, false, false], "id_plaque": [false, false, false, false, false, false]},
              {"vc_tooth": "18", "id_missing": true}]'::jsonb)) ->> 'nr_exam')::bigint;
  _r := ad.perio_exam_list(_base || jsonb_build_object('nr_patient', _pa));
  assert jsonb_array_length(_r -> 'exams') = 1 and jsonb_array_length(_r -> 'exams' -> 0 -> 'teeth') = 3, 'exame';
  assert (_r -> 'exams' -> 0 -> 'summary' ->> 'qt_teeth')::int = 2 and (_r -> 'exams' -> 0 -> 'summary' ->> 'qt_sites')::int = 12
     and (_r -> 'exams' -> 0 -> 'summary' ->> 'pc_bleeding')::numeric = 16.7
     and (_r -> 'exams' -> 0 -> 'summary' ->> 'pc_plaque')::numeric = 16.7
     and (_r -> 'exams' -> 0 -> 'summary' ->> 'vl_probing_mean')::numeric = 2.7
     and (_r -> 'exams' -> 0 -> 'summary' ->> 'qt_sites_4_5')::int = 1
     and (_r -> 'exams' -> 0 -> 'summary' ->> 'qt_sites_6')::int = 1,
    'resumo: ' || (_r -> 'exams' -> 0 -> 'summary')::text;
  assert (_r -> 'exams' -> 0 -> 'teeth' -> 0 -> 'qt_probing' ->> 2)::int = 2
     and _r -> 'exams' -> 0 -> 'teeth' -> 1 ->> 'vc_tooth' = '16'
     and jsonb_typeof(_r -> 'exams' -> 0 -> 'teeth' -> 1 -> 'qt_recession' -> 5) = 'null', 'pontos';
  perform ad.perio_exam_save(_base || jsonb_build_object('vc_action', 'U', 'nr_patient', _pa, 'nr_exam', _ex,
            'teeth', '[{"vc_tooth": "21", "qt_probing": [1, 1, 1, 1, 1, 1]}]'::jsonb));
  assert (select count(*) from od.perio_tooth where nr_company = _ca and nr_patient = _pa and nr_exam = _ex) = 1, 'substituidos';
  perform ad.perio_exam_save(_base || jsonb_build_object('vc_action', 'D', 'nr_patient', _pa, 'nr_exam', _ex));
  assert jsonb_array_length(ad.perio_exam_list(_base || jsonb_build_object('nr_patient', _pa)) -> 'exams') = 0, 'excluido';

  -- Ema: so le pacientes
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ema.chart@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
  perform set_config('test.nr_endo', _endo::text, false);
end $$;

\echo '== Ema: le, nao preenche'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _pa   bigint := current_setting('test.nr_patient')::bigint;
begin
  assert jsonb_array_length(ad.patient_chart_list(_base || jsonb_build_object('nr_patient', _pa)) -> 'charts') = 1, 'le fichas';
  assert not (ad.chart_model_list(_base) -> 'permission' ->> 'id_update')::boolean, 'nao edita modelos';
  perform pg_temp.expect_error('patient_chart_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'nr_model', current_setting('test.nr_endo')::bigint, 'vc_tooth', '11'), 'CHART_FORBIDDEN');
  perform pg_temp.expect_error('perio_exam_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa),
            'PERIO_FORBIDDEN');
  perform pg_temp.expect_error('chart_model_save', _base || '{"vc_action": "I", "vc_name": "X",
            "fields": [{"vc_label": "Y"}]}'::jsonb, 'CHART_MODEL_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.chart_model_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou chart_model_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 39_specialty_charts'
