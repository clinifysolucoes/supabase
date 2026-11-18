-- ============================================================================
-- Casos de Alinhadores (ad.aligner_save / ad.aligner_list).
--   Eli = administradora da empresa
--   Bia = recepcao (alinhadores: ler)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/47_aligners.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c5', 'eli.al@test.local', '{"name": "Eli AL"}'),
  ('00000000-0000-0000-0000-0000000000c6', 'bia.al@test.local', '{"name": "Bia AL"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;
grant execute on function pg_temp.expect_error(text, jsonb, text) to authenticated;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c5","role":"authenticated"}', true);
set local role authenticated;

\echo '== Eli: casos e situacoes'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _pa   bigint;
  _pb   bigint;
  _pr   bigint;
  _c1   bigint;
  _c2   bigint;
  _r    jsonb;
  _cs   jsonb;
  _p    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica AL"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Lia AL", "dt_birth": "1990-01-01",
           "vc_cpf": "52998224725", "vc_mobile": "41999990001"}'::jsonb) ->> 'nr_patient')::bigint;
  _pb := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Beto AL", "dt_birth": "1985-01-01",
           "vc_cpf": "11144477735", "vc_mobile": "41999990002"}'::jsonb) ->> 'nr_patient')::bigint;
  _pr := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Orto"}'::jsonb) ->> 'nr_professional')::bigint;

  perform pg_temp.expect_error('aligner_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa), 'ALIGNER_SYSTEM_REQUIRED');
  perform pg_temp.expect_error('aligner_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'vc_system', 'ClearTek',
            'qt_aligners', 10, 'qt_current', 12), 'ALIGNER_VALUE_INVALID');
  perform pg_temp.expect_error('aligner_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', 999, 'vc_system', 'X'),
            'ALIGNER_PATIENT_INVALID');

  _c1 := (ad.aligner_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _pr,
          'vc_system', 'ClearTek', 'vc_case_number', 'CT-123', 'qt_aligners', 20, 'qt_days_change', 10,
          'dt_start', '2030-01-01')) ->> 'nr_case')::bigint;
  _c2 := (ad.aligner_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pb, 'vc_system', 'Invisalign',
          'qt_aligners', 30, 'dt_start', '2030-02-01')) ->> 'nr_case')::bigint;

  -- pendencias pedem o texto
  perform pg_temp.expect_error('aligner_save', _base || jsonb_build_object('vc_action', 'U', 'nr_case', _c1, 'it_status', 3),
            'ALIGNER_PENDING_REQUIRED');
  perform ad.aligner_save(_base || jsonb_build_object('vc_action', 'U', 'nr_case', _c1, 'it_status', 3,
            'vc_pending', 'Aguardando o fabricante aprovar o setup'));
  perform ad.aligner_save(_base || jsonb_build_object('vc_action', 'U', 'nr_case', _c1, 'it_status', 4, 'qt_current', 1,
            'vc_event_text', 'Entregue o 1º alinhador'));
  perform ad.aligner_save(_base || jsonb_build_object('vc_action', 'U', 'nr_case', _c1, 'qt_current', 2));
  perform ad.aligner_save(_base || jsonb_build_object('vc_action', 'U', 'nr_case', _c2, 'it_status', 5, 'dt_finished', '2030-12-01'));

  _r := ad.aligner_list(_base);
  assert (_r -> 'totals' ->> 'qt_treatment')::int = 1 and (_r -> 'totals' ->> 'qt_finished')::int = 1
     and (_r -> 'totals' ->> 'qt_started')::int = 0, 'totais: ' || (_r -> 'totals')::text;
  select c into _cs from jsonb_array_elements(_r -> 'cases') c where (c ->> 'nr_case')::bigint = _c1;
  assert _cs ->> 'vc_patient' = 'Lia AL' and _cs ->> 'vc_professional' = 'Dra. Orto'
     and (_cs ->> 'dt_forecast')::date = date '2030-01-01' + 200
     and jsonb_array_length(_cs -> 'events') = 4 and _cs -> 'events' -> 0 ->> 'qt_current' = '2'
     and _cs -> 'events' -> 2 ->> 'vc_text' = 'Aguardando o fabricante aprovar o setup', 'caso 1: ' || _cs::text;
  select c into _cs from jsonb_array_elements(_r -> 'cases') c where (c ->> 'nr_case')::bigint = _c2;
  assert _cs ->> 'dt_finished' is not null and (_cs ->> 'qt_current')::int = 30, 'finalizado no ultimo alinhador';

  -- filtros
  assert jsonb_array_length(ad.aligner_list(_base || '{"it_status": 4}'::jsonb) -> 'cases') = 1, 'filtro situacao';
  assert jsonb_array_length(ad.aligner_list(_base || '{"dt_start": "2030-01-15"}'::jsonb) -> 'cases') = 1, 'filtro periodo';
  assert jsonb_array_length(ad.aligner_list(_base || '{"vc_search": "ct-12"}'::jsonb) -> 'cases') = 1, 'busca pelo numero';
  -- cancelado sai da lista padrao
  perform ad.aligner_save(_base || jsonb_build_object('vc_action', 'U', 'nr_case', _c2, 'it_status', 90));
  assert jsonb_array_length(ad.aligner_list(_base) -> 'cases') = 1, 'cancelado fora';

  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000015', 'id_read', true))));
  _p := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'bia.al@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _p))));
end $$;

\echo '== Bia: le, nao altera'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c6","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
begin
  assert jsonb_array_length(ad.aligner_list(_base) -> 'cases') = 1, 'Bia le';
  perform pg_temp.expect_error('aligner_save', _base || '{"vc_action": "U", "nr_case": 1, "qt_current": 3}'::jsonb, 'ALIGNER_FORBIDDEN');
end $$;

reset role;
rollback;
\o
\echo 'OK: 47_aligners'
