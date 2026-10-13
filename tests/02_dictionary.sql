-- ============================================================================
-- O dicionario de dados (docs/dictionary/schema.json) vira COMMENT ON no banco
-- (R__zz_dictionary_comments.sql). Este teste garante que o dicionario cobre
-- TODO o schema ad (e as functions de private): objeto sem comentario = esta faltando
-- no JSON. (O caminho inverso - JSON citando coluna inexistente - ja falha no
-- proprio COMMENT ON durante o flyway migrate.)
-- ============================================================================
\set ON_ERROR_STOP on
\set QUIET on

do $$
declare
  _missing text;
begin
  select string_agg(t.table_name, ', ' order by t.table_name)
    into _missing
    from information_schema.tables t
   where t.table_schema = 'ad'
     and t.table_type   = 'BASE TABLE'
     and obj_description(format('%I.%I', t.table_schema, t.table_name)::regclass, 'pg_class') is null;
  if _missing is not null then
    raise exception 'Tabelas sem descricao no dicionario: %', _missing;
  end if;

  select string_agg(c.table_name || '.' || c.column_name, ', ' order by c.table_name, c.ordinal_position)
    into _missing
    from information_schema.columns c
   where c.table_schema = 'ad'
     and col_description(format('%I.%I', c.table_schema, c.table_name)::regclass, c.ordinal_position) is null;
  if _missing is not null then
    raise exception 'Colunas sem descricao no dicionario: %', _missing;
  end if;

  select string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', ', ' order by p.proname)
    into _missing
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('ad', 'private')
     and obj_description(p.oid, 'pg_proc') is null;
  if _missing is not null then
    raise exception 'Functions sem descricao no dicionario: %', _missing;
  end if;

  select string_agg(c.relname, ', ' order by c.relname)
    into _missing
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname in ('ad', 'private')
     and c.relkind = 'r'
     and not c.relrowsecurity;
  if _missing is not null then
    raise exception 'Tabelas SEM row level security: %', _missing;
  end if;
end $$;

\echo 'OK: 02_dictionary'
