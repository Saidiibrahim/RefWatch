# Supabase candidate snapshot — 2026-07-15

## Disposition

This is a sanitized **candidate** source-state receipt, not the final export or
an import authorization. It was captured before production write quiescence and
therefore records:

- `final=false`;
- `eligible_for_import=false`;
- `writes_quiesced=false`;
- `final_export_complete=false`.

Any later candidate or final snapshot supersedes it. The final snapshot must be
newly captured after an evidenced source/Worker write stop and must share one
continuously maintained database session/boundary with the encrypted row export.

## Reproducible transaction

- MCP server/tool: Supabase `execute_sql`.
- Source project ref: `muwuzfbtmqwvwacqnofc`.
- Executed SQL SHA-256:
  `9606e1fa825960d2a848afa2a52df42847cb43add6c1dce7c22135ece3facf57`.
- SQL size: 21,969 bytes.

The exact executed bytes were not retained as a separate immutable artifact;
the mutable checked-in path named below has since been hardened. The executed
hash and size remain evidence, but this receipt does not claim the current file
is byte-identical to that execution.

After this candidate was captured, review hardening changed only catalog-mismatch
behavior: the current tracked SQL is 21,999 bytes at SHA-256
`06cca4e3467494bcc8f13cfc9d3a93bb402602dd6b567cb6a0307d40e4381b18` and
forces division-by-zero instead of returning zero rows when the exact catalog
gate is false. The executed candidate remains bound to the preceding hash. A
read-only live PostgreSQL proof on 2026-07-15 returned one row for the true gate
and SQLSTATE `22012` for the false gate; no schema or data mutation occurred.
- Database transaction timestamp: `2026-07-15T05:48:29.596939Z`.
- Statement timestamp: `2026-07-15T05:48:29.596939Z`.
- Completion observation: `2026-07-15T05:48:29.639472Z`.
- Isolation/read-only/timezone: `repeatable read` / `true` / `UTC`.
- Transaction snapshot: `9081:9081:`.
- Observed WAL LSN: `4/F4000000`; this is an observation, not an exclusive
  cutover cursor.
- Database/role: `postgres` / privileged provider connector role. RLS state is
  inventoried, but the connector bypass means it is not a client-access proof.

The executed revision handled a missing or unexpected public table by returning
no candidate row; the current tracked revision raises SQLSTATE `22012` instead.
Both use an exact sorted 39-table allowlist, server-side length-prefixed
canonical JSONB row serialization, per-table SHA-256, full schema/constraint/
index/enum/RLS/policy hashing, explicit minimized Auth-column allowlists, and a
45-second statement timeout. It returns no public row values, Auth IDs, emails,
provider IDs, passwords, tokens, metadata blobs, sessions, MFA material, or
identity JSON.

## Data and schema contracts

- Catalog exact: 39/39 tables.
- Total public rows: 1,106.
- Public data contract SHA-256:
  `069739ed82e6b37077b4259df9811cda7de16a7fbcf3824ff0f69282c36ddb63`.
- Schema contract SHA-256:
  `8bd6dfd955d67a1c0209b1c8394384036fda2a5c340181b8a3ef1658617b045d`.
- RLS contract SHA-256:
  `1261769925e4f34706b7302517dd054457a1e8b7c8f105371757f4969148eb96`.

| Public table | Rows | Row SHA-256 | RLS | Force | Policies |
| --- | ---: | --- | --- | --- | ---: |
| `ai_attachments` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `ai_messages` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `ai_threads` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `ai_usage_daily` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | off | off | 0 |
| `coaches` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | off | off | 0 |
| `coaching_sessions` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 4 |
| `competitions` | 3 | `a054d6b2d570e29d6484804af81aa92dd3a1447a76d393b625a82516e0de3d03` | on | off | 1 |
| `feedback_attachments` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | off | off | 0 |
| `feedback_items` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `feedback_threads` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `match_assessments` | 6 | `daedbbab94a285381d51ccf05885a6dee39256f5a0b0103c9a154a6248afec1b` | off | off | 0 |
| `match_events` | 579 | `a52f3bc562271c743b3b39fe0a451a5b7a01d301c2a6571490a131c8e3861a6c` | on | off | 1 |
| `match_metrics` | 62 | `ca4f88bac69ed580cd4df913a88512c4cb54b157f93d33509fcbfbaa20daca70` | on | off | 2 |
| `match_officials` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | off | off | 0 |
| `match_periods` | 119 | `72d8b03a34cbb0bc88f8092482a8c973113502e966e599e66ef5da37b465799a` | on | off | 2 |
| `match_reports` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 3 |
| `matches` | 62 | `a2fe50a5524ba9bb9332386e52271497631ed5be0051bdf8784c95cb88fb2ed9` | on | off | 2 |
| `pages` | 2 | `d8cb64fc4215165cdde00f1171f15305261e1e98139580bed71c0cd46a23ce30` | on | off | 1 |
| `reference_competitions` | 5 | `5a301bc60cf2fede25a24a7ab3d3b318e4a3e1a631f303dc34b9e0cc3c785639` | on | off | 2 |
| `reference_disciplinary_codes` | 30 | `b62e70cea1c9da852458c97c665847d721c2419850567ec3604bdb3777d9151f` | on | off | 2 |
| `reference_disciplinary_rules` | 3 | `cdd292d821a45576229148710eafdd50cca349cc6937dbfc154af6789bd16b59` | on | off | 2 |
| `reference_teams` | 54 | `d7c4caa932e521d38bfcd66c4f2ff8a2f9955982cb58350bb249779a181bcc14` | on | off | 2 |
| `resource_shares` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `scheduled_matches` | 38 | `7ad5ae687fc4722d33971cf89cdf738f05f9027d5009a98780c62bd1a26d6303` | on | off | 1 |
| `team_members` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `team_officials` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `team_tags` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `teams` | 77 | `b1f55e778de82a34b03101abfea12450ca1e81fd6e5dee291e19d12864948f78` | on | off | 1 |
| `trend_snapshots` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | off | off | 0 |
| `user_devices` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `users` | 42 | `55335f81df5809dd0848f1ed590f8368baa9c47574ccdabf883d559610867a10` | on | off | 3 |
| `venues` | 3 | `4f3f57e42a4b4cda4b2e17dd19f7d3c584dbc60c064d7a5433238692f09bc1bd` | on | off | 1 |
| `wellness_check_ins` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 5 |
| `workout_events` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | on | off | 1 |
| `workout_intensity_profile` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | off | off | 0 |
| `workout_presets` | 20 | `a3fa32ded67bc8c24db6103237884181011671cedc121ba95f4f4ccc70c28dac` | on | off | 5 |
| `workout_segments` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | off | off | 0 |
| `workout_session_metrics` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | off | off | 0 |
| `workout_sessions` | 1 | `762e3fab7686f5e10b8200501f0d5606d0f49f798e4fd0aaac6216042874810d` | on | off | 1 |

The nine RLS-disabled tables exactly match the preliminary inventory. No table
count drift was observed between that inventory and this candidate.

## Identity candidate

- Auth users: 43.
- Public profiles: 42.
- Auth identities: 44.
- Candidate auth-only count: one.
- Candidate auth-only email matches the approved `testing@refwatch.com`
  decision: true. The email and UUID are not published in the raw MCP result or
  this tracked receipt.
- Candidate auth-only owned/profile rows: zero across every current public
  `owner_id`, `user_id`, or `created_by` ownership column.
- Auth-ID set SHA-256:
  `f26dc9b2b19c44b8b9a672aa5eeba0d6e6bf02611768aafd85ec14126ebc4c58`.
- Public-user-ID set SHA-256:
  `29241569621cfc8a7cecffbf0b3ad327fa1150a703151c08725181c89961413f`.
- Minimized Auth-user contract SHA-256:
  `f64a6ccb494bbbe66362ae8e994dff694e3e5357e57380f02266aacb3243fa7f`.
- Minimized Auth-identity contract SHA-256:
  `c7c832b9e7b8f0a6182ca55b6317e966cb80ef994221b299983e626c8da434c1`.

The Auth-user digest includes only ID, normalized email, selected lifecycle/
confirmation timestamps, ban/deletion state, and SSO/anonymous flags. The
Auth-identity digest includes only identity/user IDs, provider/provider ID,
normalized email, and lifecycle/sign-in timestamps. Passwords, all tokens,
phone, metadata blobs, full identity data, sessions, refresh tokens, and MFA
data are excluded.

This is a candidate re-observation matching the preliminary identity; it is not
the final application of the exclusion. Final confirmation remains coupled to
the fresh quiesced encrypted export and reviewed Clerk mapping.

## Final export blockers preserved

The generic MCP returns query results through the connector transcript and has
no verified opaque direct-to-file export. It must not be used for full public or
Auth rows. A gitignored mode-0600 plaintext file is also insufficient.

The final export therefore remains pending a direct single-session transport
that streams into authenticated encryption with separately held key custody,
directory mode 0700, file mode 0600, no-symlink/exclusive creation, atomic
fsync/rename, exact byte framing, server/local digest parity, retention owner/
event, and verified deletion. It must be captured only after provider-confirmed
write quiescence bound to the production write guard, mutation-ledger watermark,
and provider receipts.
