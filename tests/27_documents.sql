-- ============================================================================
-- Prontuario, fase 2: modelos de documento, medicamentos e documentos do
-- paciente (render, emissao, receituario, exclusao).
--   Ana = administradora da empresa
--   Gil = recepcao (pacientes: so ler)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/27_documents.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', 'ana.doc@test.local', '{"name": "Ana Doc"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'gil.doc@test.local', '{"name": "Gil Doc"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Ana: modelos, medicamentos e documentos'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pb    jsonb;
  _pa    bigint;
  _prof  bigint;
  _nt    bigint;
  _nm    bigint;
  _nd    bigint;
  _pr    bigint;
  _body  text;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Doc"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Davi Doc", "dt_birth": "1980-02-03",
           "vc_cpf": "529.982.247-25", "vc_city": "Curitiba", "vc_state": "PR"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  _pb := _base || jsonb_build_object('nr_patient', _pa);
  _prof := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Lia", "vc_council": "CRO-PR 12345"}'::jsonb)
            ->> 'nr_professional')::bigint;

  -- modelos padrao, uma vez so
  _r := ad.document_template_list(_base);
  assert jsonb_array_length(_r -> 'templates') = 5, 'cinco modelos';
  assert (_r -> 'permission' ->> 'id_update')::boolean and _r -> 'fields' ? 'data_extenso', 'campos e permissao';
  assert jsonb_array_length(ad.document_template_list(_base) -> 'templates') = 5, 'nao duplica';

  perform pg_temp.expect_error('document_template_save', _base || '{"vc_action": "I", "it_kind": 5, "vc_name": "X", "vc_body": "x"}'::jsonb,
            'DOCUMENT_TEMPLATE_VALUE_INVALID');
  perform pg_temp.expect_error('document_template_save', _base || '{"vc_action": "I", "it_kind": 9, "vc_name": "X", "vc_body": " "}'::jsonb,
            'DOCUMENT_TEMPLATE_BODY_REQUIRED');
  _nt := (ad.document_template_save(_base || '{"vc_action": "I", "it_kind": 9, "vc_name": "Orientação pós-operatória",
            "vc_body": "{{paciente}} ({{idade}} anos), CPF {{cpf}}: repouso por {{dias}} dias. {{profissional}} {{cro}}. {{x}}"}'::jsonb)
          ->> 'nr_template')::bigint;
  assert _nt = 6, 'modelo 6';

  -- render
  _r := ad.patient_document_render(_pb || jsonb_build_object('nr_template', _nt, 'nr_professional', _prof,
          'extra', jsonb_build_object('dias', '2', 'outro', 'ignorado')));
  _body := _r ->> 'vc_body';
  assert _body like 'Davi Doc (%anos), CPF 529.982.247-25: repouso por 2 dias. Dra. Lia CRO-PR 12345. {{x}}', 'render: ' || _body;
  assert (_r ->> 'it_kind')::int = 9 and _r ->> 'vc_title' = 'Orientação pós-operatória', 'titulo e tipo';
  _r := ad.patient_document_render(_pb || '{"nr_template": 1}'::jsonb);
  assert _r ->> 'vc_body' like '%por  dia(s)%' and _r ->> 'vc_body' not like '%{{%', 'extras vazios somem';
  perform pg_temp.expect_error('patient_document_render', _pb || '{"nr_template": 99}'::jsonb, 'DOCUMENT_TEMPLATE_NOT_FOUND');

  -- medicamentos
  _r := ad.medication_list(_base);
  assert jsonb_array_length(_r -> 'medications') = 30, 'lista inicial';
  assert jsonb_array_length(ad.medication_list(_base || '{"vc_search": "amoxi"}'::jsonb) -> 'medications') = 3, 'busca';
  perform pg_temp.expect_error('medication_save', _base || '{"vc_action": "I", "vc_name": "X", "it_use": 4}'::jsonb,
            'MEDICATION_VALUE_INVALID');
  _nm := (ad.medication_save(_base || '{"vc_action": "I", "vc_name": "Tramadol", "vc_presentation": "50 mg cápsula",
            "vc_dosage": "1 cápsula de 8/8 h", "id_controlled": true}'::jsonb) ->> 'nr_medication')::bigint;
  assert _nm = 31, 'medicamento 31';
  perform ad.medication_save(_base || jsonb_build_object('vc_action', 'U', 'nr_medication', 1, 'it_status', 90));
  assert jsonb_array_length(ad.medication_list(_base) -> 'medications') = 30, 'inativo some';

  -- emissao
  perform pg_temp.expect_error('patient_document_save', _pb || '{"vc_action": "I", "it_kind": 2, "vc_title": "Receituário"}'::jsonb,
            'PATIENT_DOCUMENT_ITEMS_REQUIRED');
  perform pg_temp.expect_error('patient_document_save', _pb || '{"vc_action": "I", "it_kind": 1, "vc_title": "Atestado"}'::jsonb,
            'PATIENT_DOCUMENT_BODY_REQUIRED');
  perform pg_temp.expect_error('patient_document_save', _pb || '{"vc_action": "I", "it_kind": 2, "vc_title": "R",
            "items": [{"nr_medication": 999}]}'::jsonb, 'PATIENT_DOCUMENT_ITEM_INVALID');
  perform pg_temp.expect_error('patient_document_save', _pb || '{"vc_action": "I", "it_kind": 2, "vc_title": "R",
            "items": [{"vc_dosage": "x"}]}'::jsonb, 'PATIENT_DOCUMENT_ITEM_INVALID');
  perform ad.patient_document_save(_pb || jsonb_build_object('vc_action', 'I', 'it_kind', 9, 'nr_template', _nt,
            'vc_title', 'Orientação', 'vc_body', _body, 'nr_professional', _prof, 'dt_document', '2030-01-02'));
  _nd := (ad.patient_document_save(_pb || jsonb_build_object('vc_action', 'I', 'it_kind', 2, 'nr_template', 2,
            'vc_title', 'Receituário', 'vc_body', 'Paciente: Davi Doc', 'nr_professional', _prof, 'dt_document', '2030-01-03',
            'items', jsonb_build_array(
              jsonb_build_object('nr_medication', 11),
              jsonb_build_object('nr_medication', _nm, 'vc_dosage', '1 cápsula à noite'),
              jsonb_build_object('vc_name', 'Gelo', 'it_use', 3)))) ->> 'nr_document')::bigint;
  _r := ad.patient_document_list(_pb);
  assert jsonb_array_length(_r -> 'documents') = 2 and (_r -> 'documents' -> 0 ->> 'nr_document')::bigint = _nd, 'mais recente primeiro';
  assert jsonb_array_length(_r -> 'documents' -> 0 -> 'items') = 3, 'tres itens';
  assert _r -> 'documents' -> 0 -> 'items' -> 0 ->> 'vc_dosage' is not null
     and _r -> 'documents' -> 0 -> 'items' -> 0 ->> 'vc_name' = (select vc_name from od.medication where nr_company = _ca and nr_medication = 11),
    'completa pelo catalogo';
  assert _r -> 'documents' -> 0 -> 'items' -> 1 ->> 'vc_dosage' = '1 cápsula à noite'
     and (_r -> 'documents' -> 0 -> 'items' -> 1 ->> 'id_controlled')::boolean, 'posologia digitada e controlado';
  assert _r -> 'documents' -> 0 ->> 'vc_council' = 'CRO-PR 12345' and _r -> 'issuer' ->> 'vc_name' is not null
     and _r -> 'patient' ->> 'vc_cpf' = '52998224725', 'profissional, emitente e paciente';
  -- o modelo muda, o emitido nao
  perform ad.document_template_save(_base || jsonb_build_object('vc_action', 'U', 'nr_template', _nt, 'vc_body', 'novo'));
  assert (ad.patient_document_list(_pb) -> 'documents' -> 1 ->> 'vc_body') = _body, 'texto preservado';

  perform ad.patient_document_save(_pb || jsonb_build_object('vc_action', 'D', 'nr_document', _nd));
  assert jsonb_array_length(ad.patient_document_list(_pb) -> 'documents') = 1, 'excluido';
  perform pg_temp.expect_error('patient_document_save', _pb || jsonb_build_object('vc_action', 'D', 'nr_document', _nd),
            'PATIENT_DOCUMENT_NOT_FOUND');
  assert not exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'patient_document'
                        and (e.js_detail::text like '%repouso%' or e.vc_summary like '%repouso%')), 'log sem texto';

  -- Gil: pacientes so leitura
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'gil.doc@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Gil: le e pre-visualiza, nao emite nem configura'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _pb   jsonb;
  _r    jsonb;
begin
  _pb := _base || jsonb_build_object('nr_patient', current_setting('test.nr_patient')::bigint);
  _r := ad.patient_document_list(_pb);
  assert jsonb_array_length(_r -> 'documents') = 1 and not (_r -> 'permission' ->> 'id_create')::boolean, 'leitura';
  assert not (ad.medication_list(_base) -> 'permission' ->> 'id_update')::boolean, 'medicamentos sem editar';
  perform ad.patient_document_render(_pb || '{"nr_template": 1}'::jsonb);
  assert (select count(*) from od.patient_document) = 2, 'RLS: le os documentos da filial';
  perform pg_temp.expect_error('patient_document_save', _pb || '{"vc_action": "I", "it_kind": 1, "vc_title": "A", "vc_body": "x"}'::jsonb,
            'PATIENT_DOCUMENT_FORBIDDEN');
  perform pg_temp.expect_error('medication_save', _base || '{"vc_action": "I", "vc_name": "X"}'::jsonb, 'MEDICATION_FORBIDDEN');
  perform pg_temp.expect_error('document_template_save', _base || '{"vc_action": "U", "nr_template": 1, "vc_name": "x"}'::jsonb,
            'DOCUMENT_TEMPLATE_FORBIDDEN');
end $$;

\echo '== outra empresa nao ve'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  assert (select count(*) from od.patient_document where nr_company = current_setting('test.nr_company')::bigint) = 0, 'RLS';
  perform pg_temp.expect_error('patient_document_list', jsonb_build_object('nr_version', 1,
            'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1,
            'nr_patient', current_setting('test.nr_patient')::bigint), 'RECORD_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.patient_document_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou patient_document_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 27_documents'
