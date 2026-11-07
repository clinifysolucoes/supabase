-- ============================================================================
-- Prontuario, fase 3: fotos e exames (ad.patient_file_save / patient_file_list).
-- O Storage e a Edge Function nao entram aqui: so o registro e as regras.
--   Eva = administradora da empresa
--   Rui = recepcao (pacientes: ler e criar)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/28_patient_files.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'eva.arq@test.local', '{"name": "Eva Arq"}'),
  ('00000000-0000-0000-0000-0000000000d2', 'rui.arq@test.local', '{"name": "Rui Arq"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d1","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Eva: anexa, altera, lista e exclui'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pb    jsonb;
  _pa    bigint;
  _f1    bigint;
  _f2    bigint;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Arq"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Lia Arq", "dt_birth": "1995-05-05",
           "vc_cpf": "529.982.247-25"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  _pb := _base || jsonb_build_object('nr_patient', _pa);

  perform pg_temp.expect_error('patient_file_save', _pb || '{"vc_action": "I", "it_type": 1, "vc_name": "a.gif",
            "vc_mime": "image/gif", "qt_bytes": 10}'::jsonb, 'PATIENT_FILE_TYPE_INVALID');
  perform pg_temp.expect_error('patient_file_save', _pb || '{"vc_action": "I", "it_type": 1, "vc_name": "a.dcm",
            "vc_mime": "application/dicom", "qt_bytes": 10}'::jsonb, 'PATIENT_FILE_TYPE_INVALID');
  perform pg_temp.expect_error('patient_file_save', _pb || '{"vc_action": "I", "it_type": 1, "vc_name": "a.jpg",
            "vc_mime": "image/jpeg", "qt_bytes": 20971521}'::jsonb, 'PATIENT_FILE_TOO_LARGE');
  perform pg_temp.expect_error('patient_file_save', _pb || '{"vc_action": "I", "it_type": 1, "it_category": 11, "vc_name": "a.jpg",
            "vc_mime": "image/jpeg", "qt_bytes": 10}'::jsonb, 'PATIENT_FILE_VALUE_INVALID');
  perform pg_temp.expect_error('patient_file_save', _pb || jsonb_build_object('vc_action', 'I', 'it_type', 2, 'vc_name', 'a.pdf',
            'vc_mime', 'application/pdf', 'qt_bytes', 10, 'dt_file', current_date + 1), 'PATIENT_FILE_VALUE_INVALID');

  _r := ad.patient_file_save(_pb || '{"vc_action": "I", "it_type": 1, "it_category": 1, "vc_name": "sorriso.JPG",
          "vc_mime": "IMAGE/JPEG", "qt_bytes": 2048000, "vc_tooth": "11"}'::jsonb);
  _f1 := (_r ->> 'nr_file')::bigint;
  assert _r ->> 'vc_path' ~ ('^' || _ca || '/1/' || _pa || '/[0-9a-f-]{36}\.jpg$'), 'caminho reservado: ' || (_r ->> 'vc_path');
  _f2 := (ad.patient_file_save(_pb || '{"vc_action": "I", "it_type": 2, "it_category": 11, "vc_name": "panoramica.dcm",
          "vc_mime": "application/dicom", "qt_bytes": 15000000, "dt_file": "2026-01-10"}'::jsonb) ->> 'nr_file')::bigint;
  assert _f2 = 2, 'sequencial por paciente';

  perform ad.patient_file_save(_pb || jsonb_build_object('vc_action', 'U', 'nr_file', _f1, 'it_category', 3,
            'vc_description', 'Antes do clareamento'));
  _r := ad.patient_file_list(_pb || '{"it_type": 1}'::jsonb);
  assert jsonb_array_length(_r -> 'files') = 1 and (_r -> 'files' -> 0 ->> 'it_category')::int = 3
     and _r -> 'files' -> 0 ->> 'vc_tooth' = '11' and _r -> 'files' -> 0 ->> 'vc_mime' = 'image/jpeg', 'foto alterada';
  assert jsonb_array_length(ad.patient_file_list(_pb) -> 'files') = 2, 'todos';
  assert jsonb_array_length(ad.patient_file_list(_pb || jsonb_build_object('nr_files', jsonb_build_array(_f2))) -> 'files') = 1,
    'por lista';

  _r := ad.patient_file_save(_pb || jsonb_build_object('vc_action', 'DELETE', 'nr_file', _f2));
  assert _r ->> 'vc_path' like '%.dcm', 'devolve o caminho para apagar';
  assert jsonb_array_length(ad.patient_file_list(_pb) -> 'files') = 1, 'excluido some';
  perform pg_temp.expect_error('patient_file_save', _pb || jsonb_build_object('vc_action', 'DELETE', 'nr_file', _f2),
            'PATIENT_FILE_NOT_FOUND');
  assert exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'patient_file'
                    and e.vc_summary like 'Foto sorriso.JPG anexado%'), 'log';

  -- Rui: ler e criar
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006',
                                                          'id_read', true, 'id_create', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'rui.arq@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Rui: anexa, mas nao altera nem exclui'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000d2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _pb jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1,
                                  'nr_patient', current_setting('test.nr_patient')::bigint);
  _r  jsonb;
begin
  _r := ad.patient_file_save(_pb || '{"vc_action": "I", "it_type": 2, "vc_name": "laudo.pdf",
          "vc_mime": "application/pdf", "qt_bytes": 1000}'::jsonb);
  assert (_r ->> 'nr_file')::int = 3, 'anexou';
  _r := ad.patient_file_list(_pb);
  assert jsonb_array_length(_r -> 'files') = 2 and (_r -> 'permission' ->> 'id_create')::boolean
     and not (_r -> 'permission' ->> 'id_update')::boolean, 'permissoes';
  perform pg_temp.expect_error('patient_file_save', _pb || '{"vc_action": "DELETE", "nr_file": 1}'::jsonb, 'PATIENT_FILE_FORBIDDEN');
  perform pg_temp.expect_error('patient_file_save', _pb || '{"vc_action": "U", "nr_file": 1, "vc_tooth": "21"}'::jsonb,
            'PATIENT_FILE_FORBIDDEN');
end $$;

\echo '== outra empresa nao ve'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  assert (select count(*) from od.patient_file where nr_company = current_setting('test.nr_company')::bigint) = 0, 'RLS';
  perform pg_temp.expect_error('patient_file_list', jsonb_build_object('nr_version', 1,
            'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1,
            'nr_patient', current_setting('test.nr_patient')::bigint), 'RECORD_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.patient_file_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou patient_file_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 28_patient_files'
