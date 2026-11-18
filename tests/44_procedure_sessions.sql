-- ============================================================================
-- Prontuario: sessoes, retorno automatico e tempo de execucao
-- (ad.procedure_save, ad.budget_save, ad.clinical_evolution_save,
-- ad.patient_record_get, ad.settings_save).
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/44_procedure_sessions.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000b9', 'eli.ses@test.local', '{"name": "Eli Ses"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b9","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Eli: procedimentos com sessoes e retorno'
do $$
declare
  _ca    bigint;
  _base  jsonb;
  _pa    bigint;
  _ort   bigint;
  _lim   bigint;
  _nb    bigint;
  _r     jsonb;
  _e1    bigint;
  _e2    bigint;
  _pb    jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Ses"}'::jsonb) ->> 'nr_company')::bigint;
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Lia Ses", "dt_birth": "1990-01-01",
           "vc_cpf": "52998224725", "vc_mobile": "41999990001"}'::jsonb) ->> 'nr_patient')::bigint;
  _pb := _base || jsonb_build_object('nr_patient', _pa);

  perform pg_temp.expect_error('procedure_save', _base || '{"vc_action": "I", "vc_name": "X", "qt_sessions": 0}'::jsonb,
            'PROCEDURE_SESSIONS_INVALID');
  perform pg_temp.expect_error('procedure_save', _base || '{"vc_action": "I", "vc_name": "X", "qt_return_days": 900}'::jsonb,
            'PROCEDURE_SESSIONS_INVALID');
  _ort := (ad.procedure_save(_base || '{"vc_action": "I", "vc_name": "Manutenção ortodôntica", "qt_sessions": 3,
            "qt_return_days": 30, "vl_current_price": 150}'::jsonb) ->> 'nr_procedure')::bigint;
  _lim := (ad.procedure_save(_base || '{"vc_action": "I", "vc_name": "Limpeza", "qt_return_days": 180,
            "vl_current_price": 200}'::jsonb) ->> 'nr_procedure')::bigint;
  _r := ad.procedure_list(_base);
  assert exists (select 1 from jsonb_array_elements(_r -> 'procedures') p
                  where (p ->> 'nr_procedure')::bigint = _ort and (p ->> 'qt_sessions')::int = 3
                    and (p ->> 'qt_return_days')::int = 30), 'lista com sessoes e retorno';

  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'dt_budget', current_date,
          'items', jsonb_build_array(jsonb_build_object('nr_procedure', _ort), jsonb_build_object('nr_procedure', _lim)))))
          -> 'budget' ->> 'nr_budget')::bigint;
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 1,
            'dt_first_due', current_date + 10, 'it_payment_method', 2));
  assert (select qt_sessions from od.budget_item where nr_company = _ca and nr_budget = _nb and nr_item = 1) = 3, 'item copia sessoes';

  -- sem as opcoes ligadas: uma evolucao conclui o item, sem retorno e sem tempo
  _r := ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'Limpeza feita.', 'nr_budget', _nb,
          'nr_item', 2, 'qt_minutes', 40));
  assert (_r ->> 'id_item_done')::boolean and _r ->> 'dt_return_alert' is null and _r ->> 'nr_session' is null, 'padrao: ' || _r::text;
  assert (select qt_minutes from od.clinical_evolution where nr_company = _ca and nr_evolution = (_r ->> 'nr_evolution')::bigint) is null,
    'tempo so com a opcao';
  perform ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'D', 'nr_evolution', (_r ->> 'nr_evolution')::bigint));
  assert (select dt_done is null and qt_sessions_done = 0 from od.budget_item where nr_company = _ca and nr_budget = _nb and nr_item = 2),
    'exclusao desfaz';

  -- liga sessoes, retorno e tempo
  _r := ad.settings_save(_base || '{"id_record_sessions": true, "id_record_return": true, "id_record_time": true}'::jsonb);
  assert (_r -> 'settings' ->> 'id_record_time')::boolean, 'configuracao salva';
  assert (ad.patient_record_get(_pb) -> 'record_settings' ->> 'id_sessions')::boolean, 'prontuario sabe das sessoes';

  perform pg_temp.expect_error('clinical_evolution_save', _pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'X',
            'qt_minutes', 0), 'CLINICAL_EVOLUTION_MINUTES_INVALID');

  -- manutencao em 3 sessoes
  _r := ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'Sessão 1.', 'nr_budget', _nb,
          'nr_item', 1, 'qt_minutes', 30));
  _e1 := (_r ->> 'nr_evolution')::bigint;
  assert (_r ->> 'nr_session')::int = 1 and not (_r ->> 'id_item_done')::boolean, 'sessao 1: ' || _r::text;
  _r := ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'Sessão 2.', 'nr_budget', _nb, 'nr_item', 1));
  _e2 := (_r ->> 'nr_evolution')::bigint;
  assert (_r ->> 'nr_session')::int = 2, 'sessao 2';
  _r := ad.patient_record_get(_pb);
  assert exists (select 1 from jsonb_array_elements(_r -> 'pending_items') i
                  where (i ->> 'nr_item')::int = 1 and (i ->> 'qt_sessions_done')::int = 2 and (i ->> 'qt_sessions')::int = 3),
    'pendente com 2 de 3';
  assert exists (select 1 from jsonb_array_elements(_r -> 'evolutions') e
                  where (e ->> 'nr_evolution')::bigint = _e1 and (e ->> 'qt_minutes')::int = 30 and (e ->> 'nr_session')::int = 1),
    'evolucao com tempo e sessao';
  -- desfaz a sessao 2 e refaz
  perform ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'D', 'nr_evolution', _e2));
  assert (select qt_sessions_done from od.budget_item where nr_company = _ca and nr_budget = _nb and nr_item = 1) = 1, 'sessao desfeita';
  perform ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'Sessão 2.', 'nr_budget', _nb, 'nr_item', 1));
  _r := ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'Sessão 3.', 'nr_budget', _nb, 'nr_item', 1));
  assert (_r ->> 'nr_session')::int = 3 and (_r ->> 'id_item_done')::boolean, 'ultima sessao conclui';
  assert (_r ->> 'dt_return_alert')::date = (now() at time zone 'America/Sao_Paulo')::date + 30, 'retorno em 30 dias: ' || _r::text;
  assert (select vc_return_alert from od.patient where nr_company = _ca and nr_patient = _pa) = 'Retorno: Manutenção ortodôntica',
    'texto do retorno';

  -- limpeza (180 dias) nao empurra o retorno mais proximo
  _r := ad.clinical_evolution_save(_pb || jsonb_build_object('vc_action', 'I', 'vc_text', 'Limpeza.', 'nr_budget', _nb, 'nr_item', 2));
  assert (_r ->> 'id_item_done')::boolean and _r ->> 'dt_return_alert' is null, 'retorno mais proximo mantido';
  assert (select dt_return_alert from od.patient where nr_company = _ca and nr_patient = _pa)
         = (now() at time zone 'America/Sao_Paulo')::date + 30, 'alerta continua em 30 dias';
end $$;

reset role;
rollback;
\o
\echo 'OK: 44_procedure_sessions'
