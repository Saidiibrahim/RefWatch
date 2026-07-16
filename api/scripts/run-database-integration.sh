#!/usr/bin/env bash
set -euo pipefail

database="refwatch"
branch="ledger-rehearsal-20260715"
organization="ibrahim-aka-ajax"

for command_name in pscale jq node; do
  command -v "$command_name" >/dev/null || { printf 'Missing required command: %s\n' "$command_name" >&2; exit 1; }
done

role_name="integration-$(date +%s)"
role_id=""
cleanup_role() {
  if [[ -z "$role_id" ]]; then
    role_id=$(pscale role list "$database" "$branch" --org "$organization" --format json \
      | jq -r --arg name "$role_name" '.[] | select(.name == $name) | .id' \
      | head -n 1) || true
  fi
  if [[ -n "$role_id" ]]; then
    pscale role delete "$database" "$branch" "$role_id" --org "$organization" --force >/dev/null || true
  fi
}
trap cleanup_role EXIT INT TERM

role_json=$(pscale role create "$database" "$branch" "$role_name" \
  --org "$organization" \
  --inherited-roles pg_read_all_data,pg_write_all_data,postgres \
  --ttl 15m \
  --format json)
role_id=$(jq -er '.id' <<< "$role_json")

integration_database_url=$(ROLE_JSON="$role_json" node -e '
  const role = JSON.parse(process.env.ROLE_JSON);
  process.stdout.write(`postgresql://${encodeURIComponent(role.username)}:${encodeURIComponent(role.password)}@${role.access_host_url}/postgres?sslmode=verify-full`);
')

REFWATCH_INTEGRATION_DATABASE_URL="$integration_database_url" \
REFWATCH_ALLOW_DESTRUCTIVE_INTEGRATION_TESTS=1 \
  ./node_modules/.bin/vitest run --config vitest.integration.config.ts
