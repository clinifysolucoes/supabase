#!/usr/bin/env bash
# local-db.sh <up|migrate|test|reset|psql|down>
#
# Loop local completo sem projeto Supabase: Postgres em Docker + stubs do
# Supabase (roles anon/authenticated/service_role, schema auth, auth.uid()) +
# Flyway migrate + testes SQL de RLS. E o mesmo fluxo do CI (sql-validate.yml).
#
#   up       sobe o container postgres:16 e aplica flyway/init/00-supabase-stubs.sql
#   migrate  generate-repeatables + flyway migrate (imagem redgate/flyway:11)
#   test     roda tests/*.sql em ordem (psql -v ON_ERROR_STOP=1)
#   reset    down + up + migrate + test (ciclo completo, ~1 min)
#   psql     abre um psql interativo no container
#   down     remove o container
#
# Variaveis: PG_PORT (default 54329), PG_CONTAINER (default supabase-login-pg)
#
# Alternativa com o Supabase CLI (auth real): `supabase start` e depois
#   FLYWAY_URL=jdbc:postgresql://host.docker.internal:54322/postgres \
#   FLYWAY_USER=postgres FLYWAY_PASSWORD=postgres ./flyway/scripts/deploy.sh local

set -euo pipefail

CMD="${1:-}"
PG_PORT="${PG_PORT:-54329}"
PG_CONTAINER="${PG_CONTAINER:-supabase-login-pg}"
PG_IMAGE="postgres:16-alpine"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

export FLYWAY_URL="jdbc:postgresql://host.docker.internal:${PG_PORT}/postgres"
export FLYWAY_USER="postgres"
export FLYWAY_PASSWORD="postgres"

psql_in_container() {
  docker exec -i -e PGPASSWORD=postgres "$PG_CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 "$@"
}

do_up() {
  if docker ps -a --format '{{.Names}}' | grep -qx "$PG_CONTAINER"; then
    docker start "$PG_CONTAINER" >/dev/null
  else
    docker run -d --name "$PG_CONTAINER" \
      -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=postgres \
      -p "${PG_PORT}:5432" "$PG_IMAGE" >/dev/null
  fi
  echo -n "aguardando postgres"
  for _ in $(seq 1 30); do
    if docker exec "$PG_CONTAINER" pg_isready -U postgres -q 2>/dev/null; then echo " ok"; break; fi
    echo -n "."; sleep 1
  done
  psql_in_container -q < flyway/init/00-supabase-stubs.sql
  echo "stubs do Supabase aplicados (roles, schema auth, auth.uid())"
}

do_migrate() {
  "$SCRIPT_DIR/deploy.sh" local migrate
}

do_test() {
  local rc=0
  for f in tests/*.sql; do
    echo "==> $f"
    if psql_in_container -q < "$f"; then
      echo "    PASSOU"
    else
      echo "    FALHOU"; rc=1
    fi
  done
  return $rc
}

do_down() {
  docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
  echo "container $PG_CONTAINER removido"
}

case "$CMD" in
  up)      do_up ;;
  migrate) do_migrate ;;
  test)    do_test ;;
  reset)   do_down; do_up; do_migrate; do_test ;;
  psql)    docker exec -it -e PGPASSWORD=postgres "$PG_CONTAINER" psql -U postgres -d postgres ;;
  down)    do_down ;;
  *) echo "Uso: $0 <up|migrate|test|reset|psql|down>"; exit 1 ;;
esac
