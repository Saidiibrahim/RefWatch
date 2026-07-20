# Production Ledger-Key Escrow Preflight Audit

Date: 2026-07-17 (Australia/Adelaide)

## Authorized scope

The operator selected Cloudflare Secrets Store as the escrow target and
authorized metadata/permission verification followed by a non-disclosing stream
of the existing production mutation-ledger key from macOS Keychain. The scope
explicitly excluded a binding, deploy, existing Worker-secret change, rotation,
ledger activation, and write enablement.

## Cloudflare metadata readback

- Local Wrangler version: `4.110.0`.
- Authenticated account ID: `b08d54b822741dbf8e864503b50604a1`. <!-- gitleaks:allow; public resource identifier, not a credential -->
- The OAuth token reports `secrets_store (write)`.
- Existing store: `default_secrets_store`.
- Store ID: `d8fceaa58302487ab61b553ea16ff0f0`.
- Proposed target name:
  `REFWATCH_MUTATION_LEDGER_PRODUCTION_20260715_V1`.
- Metadata-only secret listings before and after the failed source validation
  confirmed that the proposed target name does not exist. No collision,
  creation, update, or deletion occurred.

The installed `cf` CLI was not used because version `0.1.0` exposes no Secrets
Store command. Wrangler is the installed Cloudflare tool with Secrets Store
support.

## Non-disclosing Keychain audit

Metadata readback found the expected generic-password record:

- service: `RefWatch mutation ledger production`;
- account/key ID: `production-20260715-v1`;
- description: `RefWatch production encryption key`;
- created/modified: `2026-07-15T06:57:22Z`.

The password payload was streamed directly into an in-memory shape inspection;
it was never printed, assigned to a command argument, written to a file, or
placed in evidence. The Keychain retrieval and inspection subprocesses exited
successfully. The CLI emitted only its newline delimiter and zero recovered
characters after trimming, so orchestration rejected the source precondition
and skipped the Secrets Store create command. The required 32-byte Base64 key
could not be decoded.

This proves that the named Keychain record exists but does **not** contain a
recoverable production ledger key. It does not prove whether the write-only
Worker secret contains the originally generated value. Cloudflare Worker secret
values cannot be recovered through Wrangler or the dashboard, and Cloudflare
Secrets Store values also become non-readable after creation. See:

- <https://developers.cloudflare.com/workers/configuration/secrets/>
- <https://developers.cloudflare.com/secrets-store/manage-secrets/>

## Disposition

The operation stopped before the Secrets Store create command. No empty value
was uploaded and no escrow success is claimed.

Current status must distinguish four gates:

1. **Recoverable source custody — blocked.** Securely restore the exact existing
   key from another approved source, or separately authorize a reviewed
   provider-state audit and remediation/rotation plan.
2. **Escrow copy stored — pending.** A future non-empty value may be streamed to
   the approved Secrets Store only after fail-closed source validation.
3. **Functional recovery proof — pending and separate.** An unbound
   `workers`-scoped secret is only stored/eligible to bind. A later approved
   binding or recovery-service procedure must prove non-disclosing equality/use.
4. **Production ledger activation/probe — pending and separate.** Escrow and
   recovery proof do not authorize capture, consumers, routing, or writes.

The current approval does not authorize retrying the upload, populating or
repairing Keychain, retrieving the secret through Worker code, creating a
binding, deploying, changing the Worker secret/key ID, rotating a key, reading
or mutating production ledger data, activating consumers, or enabling writes.

## Review disposition

- The final code-risk review found no high-severity issue and confirmed that no
  Secrets Store creation, binding, deploy, rotation, activation, or write was
  performed or claimed. Its wording finding was applied by distinguishing
  successful subprocess inspection from the failed source precondition.
- The final docs/evidence review confirmed the four-gate split and historical
  custody supersession. Its findings were applied by acknowledging the
  authenticated metadata-only Cloudflare readback and aligning the approval
  page with the one current non-secret recovery-path decision.

## Non-actions

- No Secrets Store secret was created, updated, duplicated, bound, or deleted.
- No Worker configuration, version, secret, route, preview URL, cron, Queue
  consumer, D1 row, or PlanetScale row changed.
- No key value, digest, fingerprint, or encoded fragment was printed or
  recorded.
- No ledger, onboarding, traffic, or write mode was enabled.
