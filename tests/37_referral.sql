-- ============================================================================
-- Controle de Indicacao (od.patient.nr_referrer, ad.referral_list,
-- ad.referral_reward_save).
--   Lia = administradora da empresa
--   Zoe = marketing (so le REFERRALS; sem Orcamentos e Financeiro)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/37_referral.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a7', 'lia.ref@test.local', '{"name": "Lia Ref"}'),
  ('00000000-0000-0000-0000-0000000000a8', 'zoe.ref@test.local', '{"name": "Zoe Ref"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a7","role":"authenticated"}', true);
set local role authenticated;

\echo '== Lia: quem indicou, conversao e recompensa'
do $$
declare
  _r     jsonb;
  _ca    bigint;
  _base  jsonb;
  _ana   bigint;
  _beto  bigint;
  _caio  bigint;
  _davi  bigint;
  _eva   bigint;
  _nb    bigint;
  _pr    bigint;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica Ref"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _ana := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Ana Ref", "dt_birth": "1980-01-01", "vc_cpf": "52998224725"}'::jsonb)
           ->> 'nr_patient')::bigint;
  _beto := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Beto Ref', 'dt_birth', '1981-01-01',
            'vc_cpf', '11144477735', 'nr_referrer', _ana)) ->> 'nr_patient')::bigint;
  _caio := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Caio Ref", "dt_birth": "1982-01-01",
            "vc_cpf": "39053344705", "it_source": 4, "vc_referral": "Dr. Paulo"}'::jsonb) ->> 'nr_patient')::bigint;
  _davi := (ad.patient_save(_base || '{"vc_action": "I", "vc_name": "Davi Ref", "dt_birth": "1983-01-01",
            "vc_cpf": "71428793860", "it_source": 2}'::jsonb) ->> 'nr_patient')::bigint;
  _eva := (ad.patient_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Eva Ref', 'dt_birth', '1984-01-01',
           'vc_cpf', '87748248800', 'nr_referrer', _ana)) ->> 'nr_patient')::bigint;
  perform set_config('test.nr_beto', _beto::text, false);

  -- quem indicou precisa ser outro paciente da filial
  perform pg_temp.expect_error('patient_save', _base || '{"vc_action": "I", "vc_name": "X", "dt_birth": "1990-01-01",
            "vc_cpf": "15350946056", "nr_referrer": 999}'::jsonb, 'PATIENT_VALUE_INVALID');
  perform pg_temp.expect_error('patient_save', _base || jsonb_build_object('vc_action', 'U', 'nr_patient', _ana,
            'nr_referrer', _ana), 'PATIENT_VALUE_INVALID');
  perform pg_temp.expect_error('patient_save', _base || jsonb_build_object('vc_action', 'U', 'nr_patient', _ana,
            'nr_referrer', 'abc'), 'PATIENT_VALUE_INVALID');
  assert (select it_source from od.patient where nr_company = _ca and nr_patient = _beto) = 4, 'origem indicacao automatica';
  _r := ad.patient_get(_base || jsonb_build_object('nr_patient', _beto));
  assert _r -> 'patient' ->> 'vc_referrer' = 'Ana Ref' and (_r -> 'patient' ->> 'nr_referrer')::bigint = _ana, 'ficha';

  -- Beto e Caio aprovam orcamento
  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _beto, 'dt_budget', current_date,
          'items', '[{"vc_description": "Implante", "vl_unit": 500}]'::jsonb))) -> 'budget' ->> 'nr_budget')::bigint;
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 1,
            'dt_first_due', current_date + 10, 'it_payment_method', 2));
  _nb := ((ad.budget_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _caio, 'dt_budget', current_date,
          'items', '[{"vc_description": "Clareamento", "vl_unit": 300}]'::jsonb))) -> 'budget' ->> 'nr_budget')::bigint;
  perform ad.budget_status(_base || jsonb_build_object('nr_budget', _nb, 'vc_action', 'ACCEPT', 'qt_installments', 1,
            'dt_first_due', current_date + 10, 'it_payment_method', 2));

  _r := ad.referral_list(_base);
  assert (_r -> 'totals' ->> 'qt_new')::int = 5 and (_r -> 'totals' ->> 'qt_referred')::int = 3
     and (_r -> 'totals' ->> 'qt_converted')::int = 2 and (_r -> 'totals' ->> 'pc_conversion')::numeric = 66.7
     and (_r -> 'totals' ->> 'qt_pending_reward')::int = 2, 'totais: ' || (_r -> 'totals')::text;
  assert _r -> 'referrers' -> 0 ->> 'vc_referrer' = 'Ana Ref' and (_r -> 'referrers' -> 0 ->> 'qt_referred')::int = 2
     and (_r -> 'referrers' -> 0 ->> 'qt_converted')::int = 1 and (_r -> 'referrers' -> 0 ->> 'vl_approved')::numeric = 500
     and (_r -> 'referrers' -> 0 ->> 'vl_received')::numeric = 0, 'ranking: ' || (_r -> 'referrers')::text;
  assert (_r -> 'referrers' -> 1 ->> 'vc_referrer') = 'Dr. Paulo', 'indicacao por nome';
  assert (select (s ->> 'qt_new')::int from jsonb_array_elements(_r -> 'by_source') s where (s ->> 'it_source')::int = 4) = 3,
    'por origem: ' || (_r -> 'by_source')::text;
  assert jsonb_array_length(ad.referral_list(_base || '{"vc_filter": "pending"}'::jsonb) -> 'referrals') = 2, 'pendentes';
  perform pg_temp.expect_error('referral_list', _base || '{"dt_start": "2020-01-01", "dt_end": "2026-01-01"}'::jsonb,
            'REFERRAL_PERIOD_INVALID');

  -- recompensa
  perform pg_temp.expect_error('referral_reward_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _beto),
            'REFERRAL_REWARD_REQUIRED');
  perform pg_temp.expect_error('referral_reward_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _davi,
            'vc_reward', 'Brinde'), 'REFERRAL_NOT_REFERRED');
  perform pg_temp.expect_error('referral_reward_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _beto,
            'vc_reward', 'Brinde', 'dt_reward', current_date + 2), 'REFERRAL_VALUE_INVALID');
  perform pg_temp.expect_error('referral_reward_save', _base || jsonb_build_object('vc_action', 'D', 'nr_patient', _beto),
            'REFERRAL_REWARD_NOT_FOUND');
  perform ad.referral_reward_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _beto,
            'vc_reward', 'Kit clareamento', 'vl_reward', 50));
  perform pg_temp.expect_error('referral_reward_save', _base || jsonb_build_object('vc_action', 'I', 'nr_patient', _beto,
            'vc_reward', 'Outro'), 'REFERRAL_ALREADY_REWARDED');
  _r := ad.referral_list(_base);
  assert (_r -> 'totals' ->> 'qt_pending_reward')::int = 1 and (_r -> 'totals' ->> 'vl_rewards')::numeric = 50
     and (_r -> 'referrers' -> 0 ->> 'qt_rewarded')::int = 1, 'recompensa: ' || (_r -> 'totals')::text;
  assert (select x ->> 'vc_reward' from jsonb_array_elements(_r -> 'referrals') x where (x ->> 'nr_patient')::bigint = _beto)
         = 'Kit clareamento', 'recompensa na lista';
  assert (select vc_referrer from od.referral_reward where nr_company = _ca and nr_patient = _beto) = 'Ana Ref', 'nome guardado';

  -- desfazer e registrar de novo
  perform ad.referral_reward_save(_base || jsonb_build_object('vc_action', 'D', 'nr_patient', _beto));
  assert (ad.referral_list(_base) -> 'totals' ->> 'qt_pending_reward')::int = 2, 'desfeita';
  perform ad.referral_reward_save(_base || jsonb_build_object('vc_action', 'I', 'nr_patient', _beto,
            'vc_reward', 'Desconto na limpeza'));
  assert (select it_status from od.referral_reward where nr_company = _ca and nr_patient = _beto) = 1, 'reativada';

  -- Zoe: so le indicacoes
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Marketing', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000014', 'id_read', true))));
  _pr := (_r ->> 'nr_profile')::bigint;
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'zoe.ref@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', _pr))));
end $$;

\echo '== Zoe: le sem valores e nao registra recompensa'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a8","role":"authenticated"}', true);
set local role authenticated;
do $$
declare
  _base jsonb := jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint, 'nr_branch', 1);
  _r    jsonb;
begin
  _r := ad.referral_list(_base);
  assert (_r -> 'totals' ->> 'qt_referred')::int = 3, 'le';
  assert jsonb_typeof(_r -> 'referrers' -> 0 -> 'vl_approved') = 'null'
     and jsonb_typeof(_r -> 'referrers' -> 0 -> 'vl_received') = 'null', 'sem valores sem permissao';
  assert not (_r -> 'permission' ->> 'id_update')::boolean, 'sem alterar';
  perform pg_temp.expect_error('referral_reward_save', _base || jsonb_build_object('vc_action', 'D',
            'nr_patient', current_setting('test.nr_beto')::bigint), 'REFERRAL_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.referral_list('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou referral_list';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 37_referral'
