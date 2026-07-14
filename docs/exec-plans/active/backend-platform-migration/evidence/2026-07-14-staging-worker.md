# Staging Worker and Hyperdrive Evidence — 2026-07-14

## Deployment

Sanitized commands run from `api/`:

```sh
./node_modules/.bin/wrangler deploy --dry-run --env staging
./node_modules/.bin/wrangler deploy --env staging
./node_modules/.bin/wrangler deployments list --env staging
./node_modules/.bin/wrangler secret list --env staging
curl -sS -i https://refwatch-api-staging.ibrahim-aka-ajax.workers.dev/health
curl -sS -i https://refwatch-api-staging.ibrahim-aka-ajax.workers.dev/health/ready
curl -sS -i https://refwatch-api-staging.ibrahim-aka-ajax.workers.dev/api/me
```

- Wrangler: `4.110.0`
- Worker: `refwatch-api-staging`
- URL: `https://refwatch-api-staging.ibrahim-aka-ajax.workers.dev`
- Current version: recorded in the provider deployment history
- Version deployed/read back: `2026-07-14T03:08Z`
- Startup time reported by deploy: 104 ms
- Non-secret variables: `REFWATCH_ENV=staging`,
  `ALLOW_UNMAPPED_CLERK_USERS=false`
- Hyperdrive binding: `HYPERDRIVE`, configuration
  `refwatch-planetscale-rehearsal-20260714`; the configuration ID remains in
  the deployment configuration rather than being duplicated in evidence
- Database target: PlanetScale `refwatch` branch
  `cutover-rehearsal-20260714`, using least-privilege runtime role
  `refwatch-worker-rehearsal`. No credential was retained in evidence.

Production `main` and a production Worker were not changed.

## Secret lifecycle

Secret-name readback contained only `CLERK_PUBLISHABLE_KEY`,
`CLERK_SECRET_KEY`, and `OPENAI_API_KEY`; values were never retained. Clerk
credentials came from the managed **development** Clerk instance. The OpenAI
key was transferred from local `.env` to Wrangler without displaying, logging,
or persisting the value. `CLERK_WEBHOOK_SIGNING_SECRET` was intentionally not
installed and no Clerk webhook was enabled before identity reconciliation.

These facts do not satisfy production Clerk domain/native-app/mapping
acceptance, webhook delivery, or assistant streaming proof.

## Endpoint readback

At `2026-07-14T03:08:35Z` after the match-sheet parity and streaming input/output bound deployment:

- `GET /health` → HTTP 200,
  `{"status":"ok","environment":"staging"}`
- `GET /health/ready` → HTTP 200,
  `{"status":"ready","database":"reachable"}`
- unauthenticated `GET /api/me` → HTTP 401,
  `{"error":"unauthorized","message":"Bearer session token required"}`

`/health/ready` proves only Worker → Hyperdrive → non-production database
`select 1` connectivity. It does not prove schema parity, Clerk identity
mapping, tenant isolation, authenticated CRUD/idempotency, assistant streaming,
match-sheet parsing, webhook delivery, or production readiness.
