-- ============================================================================
-- Redefinir senha pelo administrador (ad.user_password_reset_check, chamada
-- pela Edge Function user-password-reset antes de trocar a senha no Auth).
--   Mel = administradora da empresa A
--   Bia = usuaria so da empresa A (pode ter a senha redefinida pela Mel)
--   Caio = usuario da empresa A e da empresa B (conta compartilhada: nao)
--   Oto = usuario sem empresa
-- Roda numa unica transacao e termina com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/17_user_password_reset.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on
\pset format unaligned
\pset tuples_only on
\o /dev/null

begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000e1', 'mel.pw@test.local', '{"name": "Mel Senha"}'),
  ('00000000-0000-0000-0000-0000000000e2', 'bia.pw@test.local', '{"name": "Bia Senha"}'),
  ('00000000-0000-0000-0000-0000000000e3', 'caio.pw@test.local', '{"name": "Caio Senha"}'),
  ('00000000-0000-0000-0000-0000000000e4', 'oto.pw@test.local', '{"name": "Oto Senha"}');

create function pg_temp.expect_error(p_fn text, p_json jsonb, p_key text) returns void language plpgsql as $$
begin
  execute format('select ad.%I($1)', p_fn) using p_json;
  raise exception 'FALHA: esperava %', p_key;
exception when others then
  if sqlerrm not like '%' || p_key || '%' then raise; end if;
end $$;

-- numeros dos usuarios (lidos fora da RLS)
select set_config('test.' || split_part(vc_email, '.', 1), nr_user::text, false)
  from ad.app_user where vc_email like '%.pw@test.local';

-- Caio cria a empresa B (fica vinculado a ela)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e3","role":"authenticated"}', true);
set local role authenticated;
select ad.company_create('{"nr_version": 1, "vc_name": "Clinica B"}'::jsonb);

reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);
set local role authenticated;

\echo '== Mel: redefinir senha'
do $$
declare
  _ca   bigint;
  _base jsonb;
  _bia  bigint := current_setting('test.bia')::bigint;
  _caio bigint := current_setting('test.caio')::bigint;
  _oto  bigint := current_setting('test.oto')::bigint;
  _mel  bigint := current_setting('test.mel')::bigint;
  _r    jsonb;
begin
  _ca := (ad.company_create('{"nr_version": 1, "vc_name": "Clinica A"}'::jsonb) ->> 'nr_company')::bigint;
  perform set_config('test.nr_company', _ca::text, false);
  _base := jsonb_build_object('nr_version', 1, 'nr_company', _ca);
  perform ad.access_profile_save(_base || '{"vc_action": "I", "vc_name": "Recepção", "it_level": 10}'::jsonb);
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'bia.pw@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', 2))));
  perform ad.company_user_save(_base || jsonb_build_object('vc_action', 'I', 'vc_email', 'caio.pw@test.local',
            'branches', jsonb_build_array(jsonb_build_object('nr_branch', 1, 'nr_profile', 2))));

  perform pg_temp.expect_error('user_password_reset_check', '{"nr_version": 1}'::jsonb, 'USER_PASSWORD_COMPANY_REQUIRED');
  perform pg_temp.expect_error('user_password_reset_check', _base, 'COMPANY_USER_USER_REQUIRED');
  perform pg_temp.expect_error('user_password_reset_check', _base || jsonb_build_object('nr_user', _oto),
            'COMPANY_USER_NOT_FOUND');
  perform pg_temp.expect_error('user_password_reset_check', _base || jsonb_build_object('nr_user', _caio),
            'USER_PASSWORD_SHARED');

  _r := ad.user_password_reset_check(_base || jsonb_build_object('nr_user', _bia, 'nr_branch', 1));
  assert (_r ->> 'uu_auth') = '00000000-0000-0000-0000-0000000000e2', 'conta da Bia no Auth';
  assert exists (select 1 from ad.event_log where nr_company = _ca and vc_entity = 'app_user'
                   and vc_key = _bia::text and vc_summary like 'Senha de Bia Senha%'), 'log sem a senha';
  -- a propria senha pode
  _r := ad.user_password_reset_check(_base || jsonb_build_object('nr_user', _mel));
  assert (_r ->> 'nr_user')::bigint = _mel, 'a propria conta';
end $$;

\echo '== Bia (nao administradora) e Oto: nada'
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e2","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  perform pg_temp.expect_error('user_password_reset_check',
            jsonb_build_object('nr_version', 1, 'nr_company', current_setting('test.nr_company')::bigint,
                               'nr_user', current_setting('test.mel')::bigint),
            'USER_PASSWORD_FORBIDDEN');
end $$;

reset role;
set local role anon;
do $$
begin
  begin
    perform ad.user_password_reset_check('{"nr_version": 1}'::jsonb);
    raise exception 'FALHA: anon chamou user_password_reset_check';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
\o
\echo 'OK: 17_user_password_reset'
