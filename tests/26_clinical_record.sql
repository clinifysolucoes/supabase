-- ============================================================================
-- Prontuario, fase 1: modelos de anamnese, anamnese do paciente, evolucao
-- clinica (com item de orcamento realizado), odontograma e patient_record_get.
--   Bia = administradora da empresa
--   Leo = recepcao (pacientes: so ler)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/26_clinical_record.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b1', 'bia.pront@test.local', '{"name": "Bia Pront"}'),
  ('00000000-0000-0000-0000-0000000000b2', 'leo.pront@test.local', '{"name": "Leo Pront"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Bia: modelos, anamnese, evolucao e odontograma'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pb    jsonb;
  _pa    bigint;
  _prof  bigint;
  _proc  bigint;
  _nb    bigint;
  _nm    bigint;
  _ne    bigint;
  _mk    bigint;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Pront"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Rita Pront", "dt_birth": "1985-05-05",
           "vc_cpf": "529.982.247-25"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  _pb := _base || jsonb_build_object('nr_patient', _pa);
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dr. Caio"}'::jsonb) ->> 'nr_professional')::bigint;
  _proc := (ad.procedure_save(_base || '{"vc_action": "I", "vc_name": "Restauração", "qt_minutes": 30,
            "vl_current_price": 200}'::jsonb) ->> 'nr_procedure')::bigint;

  -- modelo Geral criado na primeira chamada, uma vez so
  _r := ad.anamnesis_model_list(_base);
  assert jsonb_array_length(_r -> 'models') = 1 and _r -> 'models' -> 0 ->> 'vc_name' = 'Geral', 'modelo geral';
  assert jsonb_array_length(_r -> 'models' -> 0 -> 'questions') = 16, '16 perguntas';
  assert (_r -> 'permission' ->> 'id_update')::boolean, 'admin edita';
  _r := ad.anamnesis_model_list(_base);
  assert jsonb_array_length(_r -> 'models') = 1, 'nao duplica';

  -- modelo proprio
  perform pg_temp.expect_error('anamnesis_model_save', _base || '{"vc_action": "I", "vc_name": "Orto"}'::jsonb,
            'ANAMNESIS_MODEL_QUESTIONS_REQUIRED');
  perform pg_temp.expect_error('anamnesis_model_save', _base || '{"vc_action": "I", "vc_name": "Orto",
            "questions": [{"vc_question": "x", "it_type": 9}]}'::jsonb, 'ANAMNESIS_QUESTION_INVALID');
  perform pg_temp.expect_error('anamnesis_model_save', _base || '{"vc_action": "I", "vc_name": " ",
            "questions": [{"vc_question": "x"}]}'::jsonb, 'ANAMNESIS_MODEL_NAME_REQUIRED');
  _nm := (ad.anamnesis_model_save(_base || '{"vc_action": "I", "vc_name": "Ortodontia", "questions": [
            {"vc_question": "Usa aparelho?", "it_type": 1},
            {"vc_question": "Alergia a níquel?", "it_type": 3, "id_alert": true},
            {"vc_question": "Expectativa", "it_type": 2, "id_alert": true}]}'::jsonb) ->> 'nr_model')::bigint;
  assert _nm = 2, 'modelo 2';
  assert not (select q.id_alert from od.anamnesis_question q where q.nr_company = _ca and q.nr_model = _nm and q.nr_question = 3),
    'texto livre nao alerta';
  perform ad.anamnesis_model_save(_base || jsonb_build_object('vc_action', 'U', 'nr_model', _nm, 'vc_name', 'Orto'));
  assert (select count(*) from od.anamnesis_question q where q.nr_company = _ca and q.nr_model = _nm) = 3, 'perguntas mantidas';

  -- anamnese do paciente: sim em alerta vira alerta
  perform pg_temp.expect_error('patient_anamnesis_save', _pb || '{"vc_action": "I", "nr_model": 99}'::jsonb,
            'ANAMNESIS_MODEL_NOT_FOUND');
  perform pg_temp.expect_error('patient_anamnesis_save', _pb || jsonb_build_object('vc_action', 'I', 'nr_model', _nm,
            'dt_filled', current_date + 1), 'PATIENT_ANAMNESIS_VALUE_INVALID');
  _r := ad.patient_anamnesis_save(_pb || jsonb_build_object('vc_action', 'I', 'nr_model', _nm, 'answers', jsonb_build_array(
          jsonb_build_object('nr_question', 1, 'id_yes', true),
          jsonb_build_object('nr_question', 2, 'id_yes', true, 'vc_text', 'Coceira com bijuteria'),
          jsonb_build_object('nr_question', 3, 'vc_text', 'Dentes alinhados'))));
  assert (_r ->> 'qt_alerts')::int = 1 and (_r ->> 'nr_anamnesis')::int = 1, 'um alerta';
  -- o modelo muda, a anamnese preenchida nao
  perform ad.anamnesis_model_save(_base || jsonb_build_object('vc_action', 'U', 'nr_model', _nm,
            'questions', '[{"vc_question": "Nova pergunta"}]'::jsonb));
  assert (select count(*) from od.patient_anamnesis_answer r where r.nr_company = _ca and r.nr_patient = _pa) = 3, 'copia preservada';

  -- evolucao: orcamento aprovado com 1 item
  _r := ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'dt_budget', '2030-03-04',
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _proc, 'vc_tooth', '36'))));
  _nb := (_r -> 'budget' ->> 'nr_budget')::bigint;
  perform pg_temp.expect_error('clinical_evolution_save', _pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'x',
            'nr_budget', _nb, 'nr_item', 1), 'CLINICAL_EVOLUTION_ITEM_INVALID');   -- ainda nao aprovado
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 1,
            'dt_first_due', '2030-03-10', 'it_payment_method', 2));
  _r := ad.patient_record_get(_pb);
  assert jsonb_array_length(_r -> 'pending_items') = 1, 'item a fazer';
  assert jsonb_array_length(_r -> 'alerts') = 1 and _r -> 'alerts' -> 0 ->> 'vc_text' = 'Coceira com bijuteria', 'alerta no prontuario';

  perform pg_temp.expect_error('clinical_evolution_save', _pb || '{"vc_action": "I", "vc_text": " "}'::jsonb,
            'CLINICAL_EVOLUTION_TEXT_REQUIRED');
  perform pg_temp.expect_error('clinical_evolution_save', _pb || '{"vc_action": "I", "vc_text": "x", "nr_professional": 99}'::jsonb,
            'CLINICAL_EVOLUTION_PROFESSIONAL_INVALID');
  perform pg_temp.expect_error('clinical_evolution_save', _pb || '{"vc_action": "I", "vc_text": "x", "nr_budget": 1}'::jsonb,
            'CLINICAL_EVOLUTION_VALUE_INVALID');
  perform pg_temp.expect_error('clinical_evolution_save', _pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'x',
            'dh_evolution', now() + interval '1 day'), 'CLINICAL_EVOLUTION_VALUE_INVALID');
  _ne := (ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'Restauração em resina na 36.',
            'nr_professional', _prof, 'vc_tooth', '36', 'nr_budget', _nb, 'nr_item', 1)) ->> 'nr_evolution')::bigint;
  _r := ad.patient_record_get(_pb);
  assert jsonb_array_length(_r -> 'pending_items') = 0 and jsonb_array_length(_r -> 'done_items') = 1, 'item realizado';
  assert (_r -> 'evolutions' -> 0 ->> 'nr_procedure')::bigint = _proc and _r -> 'evolutions' -> 0 ->> 'vc_professional' = 'Dr. Caio',
    'procedimento do item';
  perform pg_temp.expect_error('clinical_evolution_save', _pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'x',
            'nr_budget', _nb, 'nr_item', 1), 'CLINICAL_EVOLUTION_ITEM_INVALID');   -- ja realizado
  perform ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'D', 'nr_evolution', _ne));
  _r := ad.patient_record_get(_pb);
  assert jsonb_array_length(_r -> 'pending_items') = 1 and jsonb_array_length(_r -> 'evolutions') = 0, 'exclusao desmarca';
  perform pg_temp.expect_error('clinical_evolution_save', _pb || jsonb_build_object('vc_action', 'D', 'nr_evolution', _ne),
            'CLINICAL_EVOLUTION_NOT_FOUND');
  perform ad.clinical_evolution_save(_pb || '{"vc_action": "I", "vc_text": "Profilaxia."}'::jsonb);

  -- odontograma
  perform pg_temp.expect_error('tooth_mark_save', _pb || '{"vc_action": "I", "vc_tooth": "19", "it_condition": 1}'::jsonb,
            'TOOTH_MARK_TOOTH_INVALID');
  perform pg_temp.expect_error('tooth_mark_save', _pb || '{"vc_action": "I", "vc_tooth": "11", "it_condition": 11}'::jsonb,
            'TOOTH_MARK_VALUE_INVALID');
  perform pg_temp.expect_error('tooth_mark_save', _pb || '{"vc_action": "I", "vc_tooth": "11", "it_condition": 1, "vc_faces": "X"}'::jsonb,
            'TOOTH_MARK_VALUE_INVALID');
  _mk := (ad.tooth_mark_save(_pb || '{"vc_action": "I", "vc_tooth": "36", "it_condition": 1, "vc_faces": "ood",
            "it_situation": 2}'::jsonb) ->> 'nr_mark')::bigint;
  assert (select t.vc_faces from od.tooth_mark t where t.nr_company = _ca and t.nr_mark = _mk) = 'OD', 'faces sem repetir';
  perform ad.tooth_mark_save(_pb || jsonb_build_object('vc_action', 'U', 'nr_mark', _mk, 'it_condition', 2, 'it_situation', 3));
  perform ad.tooth_mark_save(_pb || '{"vc_action": "I", "vc_tooth": "55", "it_condition": 3}'::jsonb);
  _r := ad.patient_record_get(_pb);
  assert jsonb_array_length(_r -> 'marks') = 2, 'duas marcas';
  assert (_r -> 'marks' -> 0 ->> 'it_condition')::int = 2 and _r -> 'marks' -> 0 ->> 'vc_faces' = 'OD', 'alterada parcial';
  perform ad.tooth_mark_save(_pb || jsonb_build_object('vc_action', 'D', 'nr_mark', _mk));
  assert jsonb_array_length(ad.patient_record_get(_pb) -> 'marks') = 1, 'removida';

  assert exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'patient_anamnesis'), 'log anamnese';
  assert not exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'clinical_evolution'
                        and (e.js_detail::text like '%resina%' or e.vc_summary like '%resina%')), 'log sem texto clinico';

  -- Leo: pacientes so leitura
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'leo.pront@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Leo: le o prontuario, nao registra'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _pb   jsonb;
  _r    jsonb;
begin
  _pb := _base || jsonb_build_object('nr_patient', current_setting('test.nr_patient')::bigint);
  _r := ad.patient_record_get(_pb);
  assert jsonb_array_length(_r -> 'evolutions') = 1 and not (_r -> 'permission' ->> 'id_create')::boolean, 'leitura';
  _r := ad.anamnesis_model_list(_base);
  assert jsonb_array_length(_r -> 'models') = 2 and not (_r -> 'permission' ->> 'id_update')::boolean, 'modelos sem editar';
  assert (select count(*) from od.tooth_mark where it_status = 1) = 1, 'RLS: le as marcas da filial';
  perform pg_temp.expect_error('clinical_evolution_save', _pb || '{"vc_action": "I", "vc_text": "x"}'::jsonb,
            'CLINICAL_EVOLUTION_FORBIDDEN');
  perform pg_temp.expect_error('tooth_mark_save', _pb || '{"vc_action": "I", "vc_tooth": "11", "it_condition": 1}'::jsonb,
            'TOOTH_MARK_FORBIDDEN');
  perform pg_temp.expect_error('patient_anamnesis_save', _pb || '{"vc_action": "I", "nr_model": 1}'::jsonb,
            'PATIENT_ANAMNESIS_FORBIDDEN');
  perform pg_temp.expect_error('anamnesis_model_save', _base || '{"vc_action": "U", "nr_model": 1, "vc_name": "x"}'::jsonb,
            'ANAMNESIS_MODEL_FORBIDDEN');
end $$;

\echo '== outra empresa nao ve'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  assert (select count(*) from od.clinical_evolution where nr_company = current_setting('test.nr_company')::bigint) = 0, 'RLS';
  perform pg_temp.expect_error('patient_record_get', jsonb_build_object('nr_version', 1,
            'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1,
            'nr_patient', current_setting('test.nr_patient')::bigint), 'RECORD_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.patient_record_get('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou patient_record_get';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 26_clinical_record'
