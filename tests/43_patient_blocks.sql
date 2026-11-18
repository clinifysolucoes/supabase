-- ============================================================================
-- Bloqueios do paciente (od.fn_patient_block) ao agendar, no check-in e no
-- tratamento: conta vencida, conta em aberto e contrato sem assinatura
-- (ad.appointment_save, ad.clinical_evolution_save, ad.settings_save).
--   Eli = administradora da empresa
--   Bia = recepcao (agenda e pacientes: ler, criar e alterar)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/43_patient_blocks.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a7', 'eli.blk@test.local', '{"name": "Eli Blk"}'),
  ('00000000-0000-0000-0000-0000000000a8', 'bia.blk@test.local', '{"name": "Bia Blk"}');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a7","role":"authenticated"}', true);
set local role authenticated;

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

\echo '== Eli: regras, contrato e consultas'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _pa   bigint;
  _pr   bigint;
  _a1   bigint;
  _nd   bigint;
  _r    jsonb;
  _p    bigint;
  _img  text := 'data:image/png;base64,' || repeat('iVBORw0KGgoAAAANSUhEUgAA', 20);
  _t    jsonb := jsonb_build_object('dh_start', now() + interval '1 day', 'dh_end', now() + interval '1 day 30 minutes');
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Blk"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.c', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _pa := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Davi Blk", "dt_birth": "1980-02-03",
           "vc_cpf": "52998224725", "vc_mobile": "41999990001"}'::jsonb) ->> 'nr_patient')::bigint;
  perform set_config('test.pa', _pa::text, false);
  _pr := (ad.professional_save(_base || '{"vc_action": "I", "vc_name": "Dra. Lia"}'::jsonb) ->> 'nr_professional')::bigint;
  perform set_config('test.pr', _pr::text, false);

  perform pg_temp.expect_error('settings_save', _base || '{"it_treat_open_rule": 5}'::jsonb, 'SETTINGS_DEBT_INVALID');
  _r := ad.settings_save(_base || '{"it_contract_rule": 2, "it_checkin_contract_rule": 4, "it_treat_contract_rule": 3}'::jsonb);
  assert (_r -> 'settings' ->> 'it_checkin_contract_rule')::int = 4 and (_r -> 'settings' ->> 'it_treat_debt_rule')::int = 1,
    'regras salvas: ' || (_r -> 'settings')::text;

  -- sem contrato: nada barra
  _a1 := (ad.appointment_save(_base || _t || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _pr))
          ->> 'nr_appointment')::bigint;
  perform set_config('test.a1', _a1::text, false);

  -- contrato sem assinatura
  _nd := (ad.patient_document_save(_base || jsonb_build_object('nr_patient', _pa, 'vc_action', 'I', 'it_kind', 3,
            'vc_title', 'Contrato', 'vc_body', 'Texto do contrato.')) ->> 'nr_document')::bigint;
  -- agenda: avisa e devolve a pendencia
  _r := ad.appointment_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'nr_professional', _pr,
          'dh_start', now() + interval '2 days', 'dh_end', now() + interval '2 days 30 minutes'));
  assert _r -> 'debt' ->> 'vc_kind' = 'contract' and _r -> 'debt' ->> 'vc_stage' = 'agenda'
     and (_r -> 'debt' ->> 'qt_entries')::int = 1, 'aviso de contrato: ' || _r::text;
  -- check-in: bloqueia
  perform pg_temp.expect_error('appointment_save', _base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'it_status', 3),
            'APPOINTMENT_CONTRACT_BLOCKED');
  -- tratamento: administrador confirma
  perform pg_temp.expect_error('appointment_save', _base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'it_status', 4),
            'APPOINTMENT_CONTRACT_CONFIRM');
  _r := ad.appointment_save(_base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'it_status', 4,
          'id_debt_override', true));
  assert _r -> 'debt' ->> 'vc_stage' = 'treat', 'liberado pelo administrador';
  perform pg_temp.expect_error('clinical_evolution_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa,
            'vc_text', 'Atendido.'), 'CLINICAL_EVOLUTION_CONFIRM');
  _r := ad.clinical_evolution_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'vc_text', 'Atendido.',
          'id_block_override', true));
  assert _r -> 'block' ->> 'vc_kind' = 'contract', 'evolucao com aviso: ' || _r::text;

  -- assinado pelo paciente: some a pendencia
  perform ad.signature_save(_base || jsonb_build_object('nr_patient', _pa, 'it_target', 1, 'nr_document', _nd, 'it_signer', 1,
            'vc_signer_name', 'Davi Blk', 'vc_signer_cpf', '529.982.247-25', 'tx_image', _img, 'id_consent', true));
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'it_status', 3));
  _r := ad.clinical_evolution_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _pa, 'vc_text', 'Retorno.'));
  assert _r -> 'block' is null or jsonb_typeof(_r -> 'block') = 'null', 'sem pendencia apos assinar';

  -- conta vencida no check-in e no tratamento
  perform ad.settings_save(_base || '{"it_checkin_debt_rule": 2, "it_treat_debt_rule": 4}'::jsonb);
  perform ad.fin_setup(_base);

  -- Bia: agenda e pacientes
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000007', 'id_read', true, 'id_create', true, 'id_update', true),
            jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true, 'id_create', true, 'id_update', true))));
  _p := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'bia.blk@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _p))));
end $$;

reset role;
select set_config('test.cat', od.fn_fin_category_ensure(current_setting('test.c')::bigint, 1, 'Tratamentos', 1::smallint, null::smallint,
         (select nr_user from ad.app_user where uu_auth = '00000000-0000-0000-0000-0000000000a7'))::text, false);
insert into od.fin_entry (nr_company, nr_branch, nr_entry, it_kind, nr_category, nr_patient, vc_description, vl_amount, dt_due,
                          dt_competence, it_status)
values (current_setting('test.c')::bigint, 1, 900, 1, current_setting('test.cat')::bigint, current_setting('test.pa')::bigint,
        'Parcela vencida', 120, current_date - 10, current_date - 10, 1);
update od.appointment set it_status = 1
 where nr_company = current_setting('test.c')::bigint and nr_appointment = current_setting('test.a1')::bigint;

\echo '== Bia: vencida avisa no check-in e bloqueia o tratamento'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.c')::bigint, 'nr_branch', 1);
  _a1   bigint := current_setting('test.a1')::bigint;
  _r    jsonb;
begin
  _r := ad.appointment_save(_base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'it_status', 3));
  assert _r -> 'debt' ->> 'vc_kind' = 'debt' and (_r -> 'debt' ->> 'vl_total')::numeric = 120
     and _r -> 'debt' ->> 'vc_stage' = 'checkin', 'aviso no check-in: ' || _r::text;
  perform pg_temp.expect_error('appointment_save', _base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'it_status', 4),
            'APPOINTMENT_DEBT_BLOCKED');
  perform pg_temp.expect_error('clinical_evolution_save', _base || jsonb_build_object('vc_action', 'I',
            'nr_patient', current_setting('test.pa')::bigint, 'vc_text', 'Tentativa.'), 'CLINICAL_EVOLUTION_BLOCKED');
  -- mudar outra coisa sem mudar a situacao nao barra
  perform ad.appointment_save(_base || jsonb_build_object('vc_action', 'U', 'nr_appointment', _a1, 'vc_notes', 'Chegou cedo'));
end $$;

reset role;
rollback;
\o
\echo 'OK: 43_patient_blocks'
