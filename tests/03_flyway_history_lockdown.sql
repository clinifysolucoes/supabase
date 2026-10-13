-- ============================================================================
-- public.flyway_schema_history nao pode ser acessivel pela API (schema public e
-- exposto no PostgREST). Garante: RLS ligada e nenhum privilegio para anon e
-- authenticated. Ver flyway/callbacks/afterMigrate__lockdown_flyway_history.sql.
-- Uso: psql -v ON_ERROR_STOP=1 -f tests/03_flyway_history_lockdown.sql
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on

begin;

do $$
begin
  assert (select c.relrowsecurity
            from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relname = 'flyway_schema_history'),
    'RLS desligada em public.flyway_schema_history';
  assert not has_table_privilege('anon', 'public.flyway_schema_history', 'SELECT, INSERT, UPDATE, DELETE'),
    'anon tem privilegio em public.flyway_schema_history';
  assert not has_table_privilege('authenticated', 'public.flyway_schema_history', 'SELECT, INSERT, UPDATE, DELETE'),
    'authenticated tem privilegio em public.flyway_schema_history';
end $$;

set local role anon;
do $$
begin
  begin
    perform count(*) from public.flyway_schema_history;
    raise exception 'FALHA: anon conseguiu ler public.flyway_schema_history';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

rollback;
\echo 'OK: 03_flyway_history_lockdown'
