-- ============================================================================
-- Schema PRIVATE - helpers de RLS, fora da API.
--
-- Os helpers fn_current_user_nr, fn_my_branches, fn_my_companies,
-- fn_is_company_admin e fn_is_admin_of_user precisam de EXECUTE para
-- authenticated (as policies rodam como o usuario logado). Dentro de ad, que e
-- exposto no PostgREST, eles ficavam chamaveis em /rest/v1/rpc/ (lint 0029 da
-- Supabase: SECURITY DEFINER executavel por authenticated em schema exposto).
-- Em private, que NUNCA entra em Exposed schemas, continuam usaveis pelas
-- policies e somem da API.
--
--   * anon          -> NADA (sem USAGE).
--   * authenticated -> USAGE no schema + EXECUTE so no que cada .pgs conceder.
--   * service_role  -> USAGE.
--
-- As functions sao recriadas pelas repeatables em Procedures/BPRIVATE/ (R__fn_*).
-- As policies de ad dependem dos helpers: caem aqui e R__rls_policies recria no
-- mesmo migrate. Em banco novo nada disso existe e os DROP IF EXISTS sao no-op.
-- ============================================================================

create schema if not exists private;

revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;
alter default privileges in schema private revoke execute on functions from public;

drop policy if exists company_select             on ad.company;
drop policy if exists branch_select              on ad.branch;
drop policy if exists access_profile_select      on ad.access_profile;
drop policy if exists company_user_select        on ad.company_user;
drop policy if exists branch_user_profile_select on ad.branch_user_profile;
drop policy if exists app_user_select            on ad.app_user;
drop policy if exists access_log_select          on ad.access_log;

drop function if exists ad.fn_is_admin_of_user(bigint);
drop function if exists ad.fn_is_company_admin(bigint);
drop function if exists ad.fn_my_companies();
drop function if exists ad.fn_my_branches();
drop function if exists ad.fn_current_user_nr();
