-- ============================================================================
-- Schema AD (Administrative) - base multi-empresa / multi-filial.
--
-- Seguranca em primeiro lugar:
--   * anon          -> NADA (sem USAGE no schema). Sem login nao se le nem se chama nada.
--   * authenticated -> SELECT nas tabelas (filtrado por RLS) + EXECUTE apenas nas
--                      functions RPC liberadas explicitamente em Procedures/BAD/*.pgs.
--                      Nenhum INSERT/UPDATE/DELETE direto: toda escrita passa por
--                      function SECURITY DEFINER que valida.
--   * service_role  -> acesso total (so em servidor: Edge Functions / CI). Nunca no app.
-- ============================================================================

create schema if not exists ad;

revoke all on schema ad from public;
grant usage on schema ad to authenticated, service_role;

-- Privilegios default para objetos futuros criados neste schema pelo role de deploy
-- (postgres). Functions NAO ficam executaveis por PUBLIC: cada .pgs concede o que precisa.
alter default privileges in schema ad grant select on tables to authenticated;
alter default privileges in schema ad grant all on tables to service_role;
alter default privileges in schema ad grant all on sequences to service_role;
alter default privileges in schema ad revoke execute on functions from public;
