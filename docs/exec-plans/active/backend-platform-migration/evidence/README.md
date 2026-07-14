# Backend Migration Evidence Index

| Acceptance evidence | Status | Artifact |
| --- | --- | --- |
| Preliminary source inventory | Recorded | `2026-07-14-source-snapshot.md` |
| Final repeatable-read source snapshot/export boundary | Pending | — |
| Disposable PlanetScale schema rehearsal | Recorded operator result | `2026-07-14-planetscale-rehearsal.md` |
| Global reference/preset rehearsal | 53 imported rows plus 5/54 seeded catalog; business-row source/target hashes match | `2026-07-14-reference-data-rehearsal.md` |
| Independent review/dispositions | Recorded; deferred gates remain | `2026-07-14-review-dispositions.md` |
| API and Apple verification | 47 API pass; Core 110 pass/1 skip + 5 Swift Testing pass; iOS unit 89/89; iOS UI 19 pass/2 bounded skips; watch UI 11/11; watch unit 107 pass/4 explicit skips on Series 9 simulator | `2026-07-14-verification.md` |
| Durable iOS test receipts | Compact `xcresulttool` summaries retain destination and aggregate counts for final 89/89 unit and 19-pass/2-skip UI reruns | `2026-07-14-apple-test-receipts.md` |
| Final cutover-bundle validator | Explicit 39-table arrays/counts/dispositions, exact Auth-ID diff, collision-safe identity contracts, import coverage, and relation validation recorded; final bundle absent | `2026-07-14-cutover-bundle-validator.md` |
| Stripe Projects/Clerk linkage readback | Linked; production domain pending | `2026-07-14-clerk-provider-status.md` |
| Auth-only-user disposition and 42-user Clerk mapping receipt | Pending | — |
| Full source import/count/orphan/representative-bundle reconciliation | Pending | — |
| Staging Worker/Hyperdrive/readiness | Recorded connectivity proof | `2026-07-14-staging-worker.md` |
| Real Postgres match isolation/idempotency | 3/3 passed on disposable branch; Clerk/deployed and broader CRUD matrix pending | `2026-07-14-database-integration.md` |
| Staging secret-name/config readback | Clerk development + OpenAI installed; webhook and production Clerk pending | `2026-07-14-staging-worker.md` |
| Production PlanetScale apply/Hyperdrive/Worker | Pending | — |
| Worker authenticated route matrix | Pending | — |
| iOS/watch automated and physical-device matrix | iOS and Series 9 watch unit/UI simulator execution plus watch/widget `0.8.2 (1)` alignment recorded; physical iPhone/watch acceptance pending because both devices were offline | `2026-07-14-verification.md` |
| Secret and Supabase package audits | Supabase package plus two available actual-value source/config/app+watch/build-log fingerprints passed; unavailable credential values cannot be fingerprinted; legacy source names remain | `2026-07-14-verification.md` |
| Operational rollback packet and write ledger | Write gate and bounded packet validator recorded; production environment, actual external mutation ledger/probe, provider-verified versions, populated packet, and recovery build pending | `2026-07-14-rollback-readiness.md` |
| Production observation-window closeout | Pending | — |

Preliminary or operator-summary artifacts must not be used as substitutes for
the corresponding final production evidence.
