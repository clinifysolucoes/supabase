-- ============================================================================
-- Callback afterMigrate (Flyway roda depois de TODO migrate, inclusive no-op).
--
-- public.rls_auto_enable() - function criada pela propria Supabase quando o
-- projeto nasce com "RLS automatico": e a function do event trigger
-- ensure_rls (ddl_command_end), SECURITY DEFINER, com EXECUTE para anon e
-- authenticated. Como public e exposto no PostgREST, os advisors 0028/0029
-- acusam /rest/v1/rpc/rls_auto_enable.
--
--   * revoke de public/anon/authenticated (postgres e service_role mantem);
--   * o event trigger continua disparando: EXECUTE nao e checado no disparo.
-- So existe em projetos Supabase criados com essa opcao: no Postgres local/CI
-- e nos projetos sem ela o bloco e no-op. Idempotente.
--
-- Fica fora de docs/dictionary/schema.json: o dicionario cobre apenas o schema ad.
-- ============================================================================

do $$
begin
  if pg_catalog.to_regprocedure('public.rls_auto_enable()') is not null then
    revoke all on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end $$;
