-- ============================================================================
-- 2FA obrigatoria por empresa (ad.company.it_mfa_policy): private.fn_my_branches
-- tira a empresa de quem precisa do segundo fator e nao confirmou (JWT aal2),
-- ad.session_context mostra SESSION_MFA_REQUIRED e ad.company_update so liga
-- a exigencia com 2FA na sessao.
--   Mel = administradora da empresa
--   Ivo = recepcao (perfil nivel 10)
-- Termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/23_mfa.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000fd', 'mel.mfa@test.local', '{"name": "Mel MFA"}'),
  ('00000000-0000-0000-0000-0000000000fe', 'ivo.mfa@test.local', '{"name": "Ivo MFA"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

-- sessao: usuario e nivel do segundo fator
create function pg_temp.as_user(p_sub text, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
           json_build_object('sub', p_sub, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

\echo '== Mel (aal1): cria a empresa e o Ivo'
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fd', 'aal1');
set local role authenticated;
do $$
declare
  _ca   bigint;
  _base jsonb;
  _r    jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica MFA"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'nr_branch', 1);
  _r := ad.access_profile_save(_base || jsonb_build_object('vc_action', 'I', 'vc_name', 'Recepção', 'it_level', 10,
          'screens', jsonb_build_array(jsonb_build_object('uu_screen', '0d6a1f3e-1b2c-4d5e-8f90-000000000006', 'id_read', true))));
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'ivo.mfa@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', (_r ->> 'nr_profile')::bigint))));

  assert (ad.settings_get(_base) -> 'security' ->> 'it_mfa_policy')::int = 0, 'padrao: nao exige';
  assert ad.session_context('{}'::jsonb) -> 'mfa' ->> 'vc_aal' = 'aal1', 'nivel da sessao';
  -- ligar exige 2FA na propria sessao
  perform pg_temp.expect_error('company_update', jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'it_mfa_policy', 2),
            'COMPANY_UPDATE_MFA_FIRST');
  perform pg_temp.expect_error('company_update', jsonb_build_object('nr_version', 1, 'nr_company', _ca, 'it_mfa_policy', 5),
            'COMPANY_UPDATE_MFA_INVALID');
end $$;

\echo '== Mel (aal2): exige dos administradores'
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fd', 'aal2');
set local role authenticated;
do $$
begin
  perform ad.company_update(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint,
            'it_mfa_policy', 1));
  assert jsonb_array_length(ad.session_context('{}'::jsonb) -> 'companies') = 1, 'Mel com 2FA entra';
end $$;

\echo '== Mel (aal1): fica de fora; Ivo (aal1) entra'
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fd', 'aal1');
set local role authenticated;
do $$
declare
  _s jsonb := ad.session_context('{}'::jsonb);
begin
  assert jsonb_array_length(_s -> 'companies') = 0, 'admin sem 2FA nao entra';
  assert _s -> 'blocked' -> 0 ->> 'vc_reason_key' = 'SESSION_MFA_REQUIRED', 'motivo 2FA, veio ' || (_s -> 'blocked')::text;
  assert not private.fn_is_company_admin(current_setting('test.nr_company')::bigint), 'sem poder de admin';
  assert (select count(*) from ad.branch) = 0, 'RLS: sem filiais';
  perform pg_temp.expect_error('company_update', jsonb_build_object('nr_version', 1,
            'nr_company', current_setting('test.nr_company')::bigint, 'it_mfa_policy', 0), 'COMPANY_UPDATE_FORBIDDEN');
end $$;

reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fe', 'aal1');
set local role authenticated;
do $$
declare
  _s jsonb := ad.session_context('{}'::jsonb);
begin
  assert jsonb_array_length(_s -> 'companies') = 1 and jsonb_array_length(_s -> 'blocked') = 0, 'recepcao sem 2FA entra (so admins)';
end $$;

\echo '== Mel (aal2): exige de todos; Ivo precisa de 2FA'
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fd', 'aal2');
set local role authenticated;
do $$
begin
  perform ad.company_update(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint,
            'it_mfa_policy', 2));
end $$;

reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fe', 'aal1');
set local role authenticated;
do $$
declare
  _s jsonb := ad.session_context('{}'::jsonb);
begin
  assert jsonb_array_length(_s -> 'companies') = 0 and _s -> 'blocked' -> 0 ->> 'vc_reason_key' = 'SESSION_MFA_REQUIRED',
    'Ivo sem 2FA fica de fora';
  assert (select count(*) from od.patient) = 0, 'RLS: sem pacientes';
end $$;

reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fe', 'aal2');
set local role authenticated;
do $$
begin
  assert jsonb_array_length(ad.session_context('{}'::jsonb) -> 'companies') = 1, 'Ivo com 2FA entra';
end $$;

\echo '== Mel (aal2): desliga'
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fd', 'aal2');
set local role authenticated;
do $$
begin
  perform ad.company_update(jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint,
            'it_mfa_policy', 0));
  assert exists (select 1 from ad.event_log e where e.nr_company = current_setting('test.nr_company')::bigint
                    and e.vc_entity = 'company' and e.js_detail ? 'it_mfa_policy'), 'mudanca no log';
end $$;

reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000fe', 'aal1');
set local role authenticated;
do $$
begin
  assert jsonb_array_length(ad.session_context('{}'::jsonb) -> 'companies') = 1, 'desligado: Ivo entra sem 2FA';
end $$;

reset role;
rollback;
\o
\echo 'OK: 23_mfa'
