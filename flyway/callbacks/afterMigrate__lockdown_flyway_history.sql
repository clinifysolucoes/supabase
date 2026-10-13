-- ============================================================================
-- Callback afterMigrate (Flyway roda depois de TODO migrate, inclusive no-op).
--
-- public.flyway_schema_history - tabela de controle do Flyway.
-- O Supabase tem default privileges no schema public que dao SELECT/INSERT/
-- UPDATE/DELETE a anon e authenticated em toda tabela criada pelo role postgres.
-- Como public e exposto no PostgREST, a historia do Flyway nascia legivel e
-- editavel com a chave publica do app (advisor "rls_disabled_in_public").
--
-- Por que callback e nao versionada: durante o migrate o Flyway segura um
-- AccessShareLock na flyway_schema_history numa segunda conexao ("idle in
-- transaction"); o ALTER TABLE ... ENABLE ROW LEVEL SECURITY precisa de
-- AccessExclusiveLock e trava para sempre. No afterMigrate o lock ja foi solto.
--
--   * revoke de public/anon/authenticated (service_role mantem: CI e Edge Functions);
--   * RLS ligada sem policy: ninguem le ou escreve pela API.
--   O Flyway nao e afetado: roda como postgres, dono da tabela e com BYPASSRLS.
-- Idempotente: revoke de privilegio inexistente e enable RLS repetido sao no-op.
--
-- Fica fora de docs/dictionary/schema.json: o dicionario cobre apenas o schema ad.
-- Teste: tests/03_flyway_history_lockdown.sql
-- ============================================================================

revoke all on table public.flyway_schema_history from public, anon, authenticated;
alter table public.flyway_schema_history enable row level security;

-- Policy deny-all so para o lint rls_enabled_no_policy (0008) nao acusar RLS sem policy.
-- Nao muda nada na pratica: sem privilegio nem policy ja nao havia acesso pela API.
do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_policies
     where schemaname = 'public' and tablename = 'flyway_schema_history'
       and policyname = 'flyway_schema_history_no_api_access'
  ) then
    create policy flyway_schema_history_no_api_access on public.flyway_schema_history
      for all to anon, authenticated using (false) with check (false);
  end if;
end $$;
