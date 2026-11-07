-- ============================================================================
-- Assinatura eletronica simples: ad.signature_save / signature_list em
-- documento do paciente e orcamento; hash muda se o conteudo mudar.
--   Ana = administradora da empresa
--   Gil = recepcao (pacientes: so ler)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/30_signature.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f1', 'ana.sig@test.local', '{"name": "Ana Sig"}'),
  ('00000000-0000-0000-0000-0000000000f2', 'gil.sig@test.local', '{"name": "Gil Sig"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated"}', true);
select set_config('request.headers', '{"x-forwarded-for": "200.1.2.3, 10.0.0.1", "user-agent": "Tablet Teste"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Ana: assina documento e orcamento'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _pb    jsonb;
  _pa    bigint;
  _nd    bigint;
  _nb    bigint;
  _img   text := 'data:image/png;base64,' || repeat('iVBORw0KGgoAAAANSUhEUgAA', 20);
  _sig   jsonb;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Sig"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Davi Sig", "dt_birth": "1980-02-03",
           "vc_cpf": "529.982.247-25"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_patient', _pa::text, false);
  _pb := _base || jsonb_build_object('nr_patient', _pa);
  _nd := (ad.patient_document_save(_pb || '{"vc_action": "I", "it_kind": 3, "vc_title": "Contrato",
            "vc_body": "Texto do contrato."}'::jsonb) ->> 'nr_document')::bigint;
  perform set_config('test.nr_document', _nd::text, false);

  _sig := _pb || jsonb_build_object('it_target', 1, 'nr_document', _nd, 'it_signer', 1, 'vc_signer_name', 'Davi  Sig',
            'vc_signer_cpf', '529.982.247-25', 'tx_image', _img, 'id_consent', true);
  perform pg_temp.expect_error('signature_save', _sig - 'id_consent', 'SIGNATURE_CONSENT_REQUIRED');
  perform pg_temp.expect_error('signature_save', _sig || '{"tx_image": "data:image/jpeg;base64,xx"}'::jsonb, 'SIGNATURE_IMAGE_INVALID');
  perform pg_temp.expect_error('signature_save', _sig || '{"vc_signer_cpf": "111.111.111-11"}'::jsonb, 'SIGNATURE_CPF_INVALID');
  perform pg_temp.expect_error('signature_save', _sig || '{"it_signer": 7}'::jsonb, 'SIGNATURE_SIGNER_INVALID');
  perform pg_temp.expect_error('signature_save', _sig || '{"nr_document": 99}'::jsonb, 'SIGNATURE_NOT_FOUND');
  perform pg_temp.expect_error('signature_save', _sig || '{"it_target": 3}'::jsonb, 'SIGNATURE_TARGET_INVALID');

  _r := ad.signature_save(_sig);
  assert (_r ->> 'vc_hash') ~ '^[0-9a-f]{64}$' and (_r ->> 'uu_code') is not null, 'assinado';
  perform ad.signature_save(_sig || '{"it_signer": 3, "vc_signer_name": "Dra. Lia", "vc_signer_cpf": null}'::jsonb);
  _r := ad.signature_list(_pb || jsonb_build_object('it_target', 1, 'nr_document', _nd));
  assert jsonb_array_length(_r -> 'signatures') = 2, 'duas assinaturas';
  assert _r -> 'signatures' -> 0 ->> 'vc_signer_name' = 'Davi Sig' and _r -> 'signatures' -> 0 ->> 'vc_signer_cpf' = '52998224725'
     and _r -> 'signatures' -> 0 ->> 'vc_ip' = '200.1.2.3' and (_r -> 'signatures' -> 0 ->> 'id_valid')::boolean, 'dados e valida';
  assert (select s.vc_user_agent from od.signature s where s.nr_company = _ca and s.nr_signature = 1) = 'Tablet Teste', 'navegador';
  assert (ad.patient_document_list(_pb) -> 'documents' -> 0 ->> 'qt_signatures')::int = 2, 'contagem na lista';
  assert not exists (select 1 from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'signature'
                        and e.js_detail::text like '%base64%'), 'log sem imagem';

  -- orcamento: assina, altera (em aberto), a assinatura deixa de valer
  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'dt_budget', '2030-03-04',
          'items', '[{"vc_description": "Clareamento", "vl_unit": 500}]'::jsonb))) -> 'budget' ->> 'nr_budget')::bigint;
  perform ad.signature_save(_base || jsonb_build_object('it_target', 2, 'nr_budget', _nb, 'it_signer', 1,
            'vc_signer_name', 'Davi Sig', 'tx_image', _img, 'id_consent', true));
  _r := ad.signature_list(_base || jsonb_build_object('it_target', 2, 'nr_budget', _nb));
  assert (_r -> 'signatures' -> 0 ->> 'id_valid')::boolean, 'orcamento valido';
  perform ad.budget_save(_base || jsonb_build_object('vc_action', 'U', 'nr_budget', _nb,
            'items', '[{"vc_description": "Clareamento", "vl_unit": 600}]'::jsonb));
  _r := ad.signature_list(_base || jsonb_build_object('it_target', 2, 'nr_budget', _nb));
  assert not (_r -> 'signatures' -> 0 ->> 'id_valid')::boolean, 'conteudo mudou depois da assinatura';
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'REFUSE'));
  perform pg_temp.expect_error('signature_save', _base || jsonb_build_object('it_target', 2, 'nr_budget', _nb, 'it_signer', 1,
            'vc_signer_name', 'Davi Sig', 'tx_image', _img, 'id_consent', true), 'SIGNATURE_STATUS_INVALID');

  -- documento excluido nao recebe assinatura
  perform ad.patient_document_save(_pb || jsonb_build_object('vc_action', 'D', 'nr_document', _nd));
  perform pg_temp.expect_error('signature_save', _sig, 'SIGNATURE_STATUS_INVALID');

  -- Gil: pacientes so leitura
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'gil.sig@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
  perform set_config('test.nr_budget', _nb::text, false);
end $$;

\echo '== Gil: le, nao assina; sem BUDGETS nao ve o orcamento'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f2","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _pb jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1,
                                  'nr_patient', current_setting('test.nr_patient')::bigint);
begin
  assert jsonb_array_length(ad.signature_list(_pb || jsonb_build_object('it_target', 1,
           'nr_document', current_setting('test.nr_document')::bigint)) -> 'signatures') = 2, 'le';
  perform pg_temp.expect_error('signature_save', _pb || jsonb_build_object('it_target', 1,
            'nr_document', current_setting('test.nr_document')::bigint, 'it_signer', 1, 'vc_signer_name', 'X Y Z',
            'tx_image', 'data:image/png;base64,AAAA', 'id_consent', true), 'SIGNATURE_FORBIDDEN');
  perform pg_temp.expect_error('signature_list', _pb || jsonb_build_object('it_target', 2,
            'nr_budget', current_setting('test.nr_budget')::bigint), 'SIGNATURE_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.signature_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou signature_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 30_signature'
