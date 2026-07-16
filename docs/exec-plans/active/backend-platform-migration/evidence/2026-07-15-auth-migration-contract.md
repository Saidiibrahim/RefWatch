# Supabase Auth to Clerk migration contract — 2026-07-15

## Read-only live evidence

At `2026-07-15T06:34:16Z`, two sanitized Supabase MCP queries ran inside
`REPEATABLE READ, READ ONLY` transactions. They returned aggregate algorithm
and provider counts only; no user ID, email, provider ID, password digest, token,
or metadata value entered the transcript.

| Source contract | Count |
| --- | ---: |
| Auth users with a `$2a$` bcrypt digest | 13 |
| Auth users without a password digest | 30 |
| Email identities | 13 |
| Apple identities | 22 |
| Google identities | 9 |

All 22 Apple, 13 email, and 9 Google identity records have an identity email
that matches their corresponding normalized `auth.users.email`; none has a
missing identity email. The total remains 43 Auth users and 44 identities.

## Target contract

- The encrypted final bundle must contain the exact Auth-user and identity rows
  needed for migration, never plaintext evidence or terminal output.
- Auth-user fields are allowlisted. Existing password material is accepted only
  when it is a syntactically valid bcrypt digest and is labelled
  `password_hasher: "bcrypt"`; absent digests remain absent.
- Identity fields are allowlisted to UUIDs, normalized email, provider,
  provider ID, and lifecycle timestamps. Tokens and raw identity/metadata JSON
  are forbidden. Every identity email must be non-null and exactly equal its
  parent Auth user's normalized email.
- Providers and password digests are fail-closed to the observed aggregate
  contract: 22 Apple, 13 email, and 9 Google identities; 13 `$2a$` bcrypt
  digests and 30 missing digests. The encrypted rows, final snapshot, and
  independently injected release policy must all agree with those counts.
  `$2b$`, `$2y$`, and bcrypt costs outside 04–31 are rejected.
- Existing app-user UUIDs become Clerk `external_id`/reviewed mapping inputs;
  Clerk subjects remain opaque and are never parsed as UUIDs.
- The one approved auth-only `testing@refwatch.com` identity remains excluded
  from target creation and must still prove no public profile and zero owned or
  referenced rows in the final boundary.

Clerk's current Backend API supports bcrypt password-digest migration through
`createUser`, allowing the 13 password identities to retain their passwords.
Apple and Google external-account credentials are not copied from Supabase;
production connections must be configured in Clerk, and a returning user
reauthorizes the provider. Clerk can link a verified OAuth email to the existing
verified-email Clerk user, but that behavior must be proved with migrated Apple
and Google acceptance fixtures before traffic cutover.

Official references:

- <https://clerk.com/docs/reference/backend/user/create-user>
- <https://clerk.com/docs/guides/development/migrating/overview>
- <https://clerk.com/docs/guides/configure/auth-strategies/social-connections/account-linking>
- <https://clerk.com/docs/guides/configure/auth-strategies/social-connections/apple>
- <https://clerk.com/docs/guides/configure/auth-strategies/social-connections/google>

## Status

This is a read-only contract and validator preparation. No Clerk user was
created, changed, merged, or deleted. The approved production-foundation action
may configure production connection credentials, but sign-up/sign-in stays
unavailable until a later approval so this action cannot implicitly create
identities. The 42-user import, subject mapping, connection enablement, and
migrated email/password/Apple/Google sign-in acceptance remain separately
approval-gated.
