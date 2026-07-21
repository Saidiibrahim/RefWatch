#!/usr/bin/env bash
set -euo pipefail

for command_name in initdb pg_ctl pg_isready psql; do
  command -v "$command_name" >/dev/null || {
    printf 'Missing required local PostgreSQL command: %s\n' "$command_name" >&2
    exit 1
  }
done

umask 077
workspace=$(mktemp -d "${TMPDIR:-/tmp}/refwatch-migration-0017-db.XXXXXX")
data_directory="$workspace/postgres"
log_file="$workspace/postgres.log"
port=""

cleanup() {
  if [[ -d "$data_directory" ]]; then
    pg_ctl -D "$data_directory" -m immediate -w stop >/dev/null 2>&1 || true
  fi
  rm -rf "$workspace"
}
trap cleanup EXIT INT TERM

for _ in {1..20}; do
  candidate=$((49152 + RANDOM % 15000))
  if ! pg_isready -h 127.0.0.1 -p "$candidate" >/dev/null 2>&1; then
    port="$candidate"
    break
  fi
done
if [[ -z "$port" ]]; then
  printf 'Unable to reserve a loopback PostgreSQL port\n' >&2
  exit 1
fi

initdb -D "$data_directory" -U postgres -A trust --no-locale -E UTF8 >/dev/null
pg_ctl -D "$data_directory" -l "$log_file" \
  -o "-h 127.0.0.1 -p $port -k $workspace -F" -w start >/dev/null

database_url="postgresql://postgres@127.0.0.1:${port}/postgres?sslmode=disable"
REFWATCH_ALLOW_LOCAL_DATABASE_TESTS=1 \
REFWATCH_MIGRATION_0017_LOCAL_DATABASE_URL="$database_url" \
  ./node_modules/.bin/vitest run \
    --config vitest.production-migration-0017-database.config.ts
