-- ============================================================================
-- Consulta de credito (ad.credit_check_request / credit_check_result /
-- credit_check_list e id_credit_check em ad.settings_save/get).
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/50_credit_check.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000f5', 'cris.cr@test.local', '{"name": "Cris Credito"}'),
  ('00000000-0000-0000-0000-0000000000f6', 'otto.cr@test.local', '{"name": "Otto Outro"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f5","role":"authenticated"}', true);
set local role authenticated;

\echo '== Cris: liga a consulta e abre'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _pa   bigint;
  _r    jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Credito"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Credito", "dt_birth": "1985-02-02",
           "vc_cpf": "529.982.247-25", "vc_mobile": "41999990001"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.pa', _pa::text, false);
  _base := _base || jsonb_build_object('nr_patient', _pa);

  -- desligada por padrao
  _r := ad.credit_check_list(_base);
  assert not (_r ->> 'id_enabled')::boolean and (_r ->> 'id_can_check')::boolean
     and jsonb_array_length(_r -> 'checks') = 0, 'lista vazia: ' || _r::text;
  assert not (ad.settings_get(_base - 'nr_patient') -> 'settings' ->> 'id_credit_check')::boolean, 'padrao desligado';
  perform pg_temp.expect_error('credit_check_request', _base || '{"id_consent": true, "it_provider": 1}'::jsonb,
                               'CREDIT_DISABLED');

  perform ad.settings_save(_base - 'nr_patient' || '{"id_credit_check": true}'::jsonb);
  assert (ad.settings_get(_base - 'nr_patient') -> 'settings' ->> 'id_credit_check')::boolean, 'ligada';

  perform pg_temp.expect_error('credit_check_request', _base || '{"it_provider": 1}'::jsonb, 'CREDIT_CONSENT_REQUIRED');
  perform pg_temp.expect_error('credit_check_request', _base || '{"id_consent": "sim", "it_provider": 1}'::jsonb,
                               'CREDIT_CONSENT_REQUIRED');
  perform pg_temp.expect_error('credit_check_request', _base || '{"id_consent": true, "it_provider": 7}'::jsonb,
                               'CREDIT_PROVIDER_INVALID');
  perform pg_temp.expect_error('credit_check_request', _base || '{"id_consent": true, "it_provider": 1, "nr_patient": 999}'::jsonb,
                               'CREDIT_PATIENT_INVALID');

  _r := ad.credit_check_request(_base || '{"id_consent": true, "it_provider": 1}'::jsonb);
  assert (_r ->> 'nr_check')::int = 1 and _r ->> 'vc_document' = '52998224725' and _r ->> 'vc_name' = 'Ana Credito',
    'aberta: ' || _r::text;
  -- outra logo em seguida: pendente
  perform pg_temp.expect_error('credit_check_request', _base || '{"id_consent": true, "it_provider": 1}'::jsonb,
                               'CREDIT_PENDING');
  -- o app nao grava resultado
  perform pg_temp.expect_error('credit_check_result', _base || '{"nr_check": 1, "it_status": 2, "it_result": 1}'::jsonb,
                               'permission denied');
  assert (select count(*) from ad.event_log e where e.nr_company = _ca and e.vc_entity = 'credit_check'
            and e.vc_summary not like '%52998224725%') = 1, 'event_log sem CPF';
end $$;

reset role;

\echo '== service_role grava os resultados'
set local role service_role;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  perform pg_temp.expect_error('credit_check_result', _base || '{"nr_check": 1, "it_status": 1}'::jsonb, 'CREDIT_VALUE_INVALID');
  perform pg_temp.expect_error('credit_check_result', _base || '{"nr_check": 1, "it_status": 2}'::jsonb, 'CREDIT_VALUE_INVALID');
  perform pg_temp.expect_error('credit_check_result', _base || '{"nr_check": 9, "it_status": 9}'::jsonb, 'CREDIT_NOT_FOUND');
  _r := ad.credit_check_result(_base || '{"nr_check": 1, "it_status": 9, "vc_error": "CREDIT_NOT_CONFIGURED"}'::jsonb);
  assert (_r ->> 'it_status')::int = 9, 'erro gravado';
  -- ja fechada: nao muda mais
  perform pg_temp.expect_error('credit_check_result', _base || '{"nr_check": 1, "it_status": 2, "it_result": 1}'::jsonb,
                               'CREDIT_NOT_FOUND');
end $$;
reset role;

\echo '== Cris: nova consulta concluida e a lista'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f5","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1,
                                    'nr_patient', current_setting('test.pa')::bigint);
begin
  -- a anterior falhou (nao pendente): pode abrir outra
  perform ad.credit_check_request(_base || '{"id_consent": true, "it_provider": 2}'::jsonb);
end $$;
reset role;
set local role service_role;
select ad.credit_check_result(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint,
         'nr_branch', 1, 'nr_check', 2, 'it_status', 2, 'it_result', 2, 'qt_score', 420, 'qt_debts', 2,
         'vl_debts', 1530.456, 'vc_protocol', 'SPC-123', 'js_detail', '{"credores": ["Loja X", "Banco Y"]}'::jsonb));
reset role;
set local role authenticated;
do $$
declare
  _r jsonb := ad.credit_check_list(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint,
                                   'nr_branch', 1, 'nr_patient', current_setting('test.pa')::bigint));
  _c jsonb;
begin
  assert (_r ->> 'id_enabled')::boolean and jsonb_array_length(_r -> 'checks') = 2, 'duas: ' || _r::text;
  _c := _r -> 'checks' -> 0;
  assert (_c ->> 'nr_check')::int = 2 and (_c ->> 'it_status')::int = 2 and (_c ->> 'it_result')::int = 2
     and (_c ->> 'qt_score')::int = 420 and (_c ->> 'vl_debts')::numeric = 1530.46
     and _c ->> 'vc_document_masked' = '***.982.247-**' and _c ->> 'vc_user' = 'Cris Credito'
     and _c -> 'js_detail' -> 'credores' ->> 1 = 'Banco Y', 'concluida: ' || _c::text;
  assert _r -> 'checks' -> 1 ->> 'vc_error' = 'CREDIT_NOT_CONFIGURED', 'erro na lista';
end $$;

\echo '== Otto (outra empresa) nao ve nem consulta'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000f6","role":"authenticated"}', true);
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1,
                                    'nr_patient', current_setting('test.pa')::bigint);
begin
  perform pg_temp.expect_error('credit_check_list', _base, 'CREDIT_FORBIDDEN');
  perform pg_temp.expect_error('credit_check_request', _base || '{"id_consent": true, "it_provider": 1}'::jsonb,
                               'CREDIT_FORBIDDEN');
  assert (select count(*) from od.credit_check) = 0, 'RLS esconde as consultas';
end $$;

rollback;
\o
\echo 'OK: 50_credit_check'
