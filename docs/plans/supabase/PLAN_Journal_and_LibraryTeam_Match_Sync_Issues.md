# Investigation Report: Journal & Library Sync Issues

**Date**: October 2, 2025 (Updated)
**Status**: Investigation Updated with New Findings
**Priority**: High

---

## Executive Summary

Testing the RefZone iOS app revealed **three critical gaps** in the Supabase integration:

1. **Journal/Assessment entries are not saved to Supabase** - they remain local-only
2. **Competitions and Venues are not being pulled from Supabase** - remote data exists but doesn't sync to local SwiftData store
3. **Potential FK validation issues** (masked by issue #2) - matches may fail to save team/competition/venue foreign keys if entities aren't synced

---

## Issue #1: Journal Feature Not Connected to Supabase

### Problem Statement
When users complete a journal/assessment after a match, the entries are stored only in local SwiftData and never synced to the Supabase backend.

### Root Cause Analysis

**Current Implementation**:
- `JournalEditorView.swift:15` uses `@Environment(\.journalStore)`
- Environment is wired to `SwiftDataJournalStore` (local-only implementation)
- No Supabase repository layer exists for journals

**Database Schema**: The `match_assessments` table exists and is properly migrated, but no application code syncs to it.

### Impact
- Journal entries are device-local only
- Data not accessible from other devices
- User expectations broken (they expect cloud sync given sign-in requirement)

### Architecture Gap
- ✅ `SupabaseMatchHistoryRepository` exists
- ✅ `SupabaseTeamLibraryRepository` exists
- ✅ `SupabaseCompetitionLibraryRepository` exists
- ✅ `SupabaseVenueLibraryRepository` exists
- ❌ **Missing**: `SupabaseJournalRepository`

---

## Issue #2: Competitions and Venues Not Syncing from Supabase 🔴

**This is the critical blocker preventing normal workflow.**

### Problem Statement

Competitions and venues **ARE** being created in Supabase successfully, but they are **NOT being pulled down** to the local SwiftData store.

This causes them to appear missing in:
- Settings → Library → Competitions (shows "No Competitions")
- Settings → Library → Venues (shows "No Venues") 
- Match Setup pickers (both show empty states)

**Evidence from Database**:
```sql
-- Verified data EXISTS in Supabase:
SELECT id, name, created_at, owner_id FROM competitions;
-- Returns: NPL (created 2025-10-01, owner = 22fe9306-52cd-493f-830b-916a3c271371)

SELECT id, name, created_at, owner_id FROM venues;
-- Returns: Marden Sports Complex (created 2025-10-01, owner = 22fe9306-52cd-493f-830b-916a3c271371)
```

Both records exist in Supabase with the correct `owner_id`.

### Root Cause Analysis

**Repository Architecture** (`SupabaseCompetitionLibraryRepository.swift:144-160`):

```swift
func scheduleInitialSync() {
    scheduleProcessingTask()
    Task { [weak self] in
        await self?.performInitialSync()
    }
}

func performInitialSync() async {
    guard let ownerUUID else { return }
    do {
        try await flushPendingDeletions()
        try await pushDirtyCompetitions()
        try await pullRemoteUpdates(for: ownerUUID)  // ← This should pull remote data
    } catch {
        log.error("Initial sync failed: ...")
    }
}
```

**The Problem**: Remote pull logic exists but the data still never populates. Our current suspicion is that the existing pull path is executing but either returning an empty result set or failing silently. We need hard evidence before altering the sync flow.

Potential failure modes to verify:

1. **Silent fetch failures** – `pullRemoteUpdates` swallows errors inside `performInitialSync()`. We need structured logging/metrics around the `api.fetchCompetitions` response, including row counts and any Supabase errors, so we can confirm whether the fetch succeeds.

2. **Cursor misbehaviour** – `remoteCursor` starts as `nil`, but if any stale value is being restored (e.g. via backlog), `fetchCompetitions(updatedAfter:)` could filter everything out. Instrumenting the cursor value and first page payload will confirm.

3. **No follow-up pulls** – Initial pulls should fire via `handleAuthState(.signedIn)` even if auth resolves after repository init, but there is still no safety net when the initial attempt fails. Once we have telemetry we can decide whether additional triggers (foreground refresh, periodic timer) are required.

**UI Layer** (`CompetitionPickerSheet.swift:97-107`):
```swift
private func loadCompetitions() {
    isLoading = true
    do {
        competitions = try competitionStore.loadAll()  // ← Reads LOCAL only
    } catch {
        loadError = error.localizedDescription
    }
    isLoading = false
}
```

Pickers **never trigger a remote pull**. They rely entirely on background sync having already populated the local store.

### Why Teams Work But Competitions/Venues Don't

**Teams sync successfully** because they're typically created locally first (via iOS app), which:
1. Triggers a local save
2. Enqueues a push to Supabase
3. Processing queue starts
4. After push completes, pull happens as part of queue processing

**Competitions/Venues still appear missing** when created remotely (direct DB insert, web admin, another device):
- No local dirty record to push
- Processing queue never runs a push, so we depend entirely on the remote pull
- Without instrumentation we cannot confirm whether the pull completes, returns empty, or errors out

### Impact
- Users cannot select competitions/venues when creating matches
- Library screens show empty despite data existing remotely
- UX completely broken for multi-device scenarios

---

## Issue #3: Potential Library Entity FK Validation Issues (Masked)

**Status**: Cannot test until Issue #2 is resolved.

### Problem Statement
When users create a match by selecting teams/competitions/venues from their library, foreign keys may be NULL if the selected entities haven't synced to Supabase yet.

**Current Observation**: Matches save successfully with `competition_id: null` and `venue_id: null` because users cannot select these entities (they don't appear in UI due to Issue #2).

**Timing Problem** (from original analysis):
1. User creates competition locally
2. Async sync to Supabase starts
3. User immediately selects competition in Match Setup
4. Match saves with local UUID `abc-123`
5. Supabase rejects FK constraint (UUID doesn't exist remotely yet)
6. Match saves with `null` FK as fallback

This issue will surface once Issue #2 is fixed and entities become selectable.

---

## Recommended Solutions

### Priority Order

**Phase 1: Critical Fixes**
1. **Issue #2** - Fix competition/venue pull (unblocks workflow) - **4-7 hours**
2. **Issue #1** - Implement journal sync - **6-8 hours**
3. **Issue #3** - Add FK validation - **8-10 hours**

---

## Solution for Issue #2: Fix Competition/Venue Remote Pull

**Status:** ✅ Completed — instrumentation shipped and remote pulls now log telemetry for debugging.

**Status:** ✅ Completed — instrumentation added and repository pulls now capture detailed telemetry.

### Approach A: Instrument the Existing Pull Path ⭐ **Recommended**

**Goal**: Confirm whether `performInitialSync()` fires and why `pullRemoteUpdates` fails to materialise records.

**Steps**:
- Add structured logging / metrics around the three stages inside `performInitialSync()` (flush, push, pull). Include the cursor value and number of rows returned from `api.fetchCompetitions` / `api.fetchVenues`.
- Surface failures by rethrowing or routing `error` through `log.error` with context (HTTP code, response body) so we can distinguish auth vs. data issues.
- Consider temporarily exposing a debug flag that forces `remoteCursor = nil` before the first pull to rule out cursor drift.
- Run on device/simulator with existing Supabase data to capture logs. If pulls return zero rows, capture the raw REST request for further investigation.

**Why This Helps**:
- Validates assumptions before we alter sync ordering
- Gives us guardrails for future telemetry/alerting
- Keeps the architecture stable while we root-cause the real failure

**Estimated Effort**: 2–3 hours (includes validation run)

---

### Approach B: Add Pull-on-Demand in UI (Complementary)

**Files**: `CompetitionPickerSheet.swift:97-107` and `VenuePickerSheet.swift:111-121`

Add protocol method (default no-op for stores that do not talk to Supabase so previews/watchOS remain happy):
```swift
// In CompetitionLibraryStoring.swift
protocol CompetitionLibraryStoring {
    // ... existing methods
    func pullNow() async throws  // ✅ NEW (default implementation throws UnsupportedOperation)
}
```

Implement in repository:
```swift
// In SupabaseCompetitionLibraryRepository.swift
func pullNow() async throws {
    guard let ownerUUID else {
        throw LibraryError.notAuthenticated
    }
    try await pullRemoteUpdates(for: ownerUUID)
}
```

Add `LibraryError.notSupported` to cover stores that cannot refresh remotely (used by previews/in-memory stores).

Update picker:
```swift
@State private var pullError: Error?

private func loadCompetitions() {
    isLoading = true
    loadError = nil
    pullError = nil

    Task {
        // ✅ Pull from remote first via protocol
        do {
            try await competitionStore.pullNow()
        } catch LibraryError.notSupported {
            // Non-Supabase stores simply skip the remote refresh
        } catch {
            // Don't block showing cached data
            pullError = error
        }

        // Then load local
        await MainActor.run {
            do {
                competitions = try competitionStore.loadAll()
            } catch {
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }
}
```

Add lightweight UI to surface `pullError` (toast/banner) if needed so QA can see network issues.

**Why This Helps**:
- Guarantees fresh data when user opens picker
- Works even if sign-in pull failed
- Better UX for multi-device scenarios

**Estimated Effort**: 3 hours

---

### Approach C: Add Periodic Background Pull (Long-term)

Add timer-based pull every 5 minutes (similar to match history):

```swift
private var pullTimer: Timer?

func scheduleInitialSync() {
    // ... existing code

    // ✅ ADD: Periodic pull
    pullTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
        Task { @MainActor [weak self] in
            guard let self, let ownerUUID = self.ownerUUID else { return }
            do {
                try await self.pullRemoteUpdates(for: ownerUUID)
            } catch {
                self.log.error("Periodic pull failed: \(error.localizedDescription)")
            }
        }
    }
}

deinit {
    pullTimer?.invalidate()  // ✅ ADD
    // ... existing cleanup
}
```

**Estimated Effort**: 2 hours

---

### Recommended Implementation

**Immediate (this week)**:
- ✅ Implement Approach A (instrumentation) and collect logs with existing Supabase data

**Short-term (once root cause confirmed)**:
- ✅ Apply remediation based on findings (likely Approach B for user-triggered refresh, optionally periodic pulls if needed)

**Optional (if multi-device use is common)**:
- ⚪ Implement Approach C (periodic pull)

**Total effort**: 4-7 hours depending on investigative findings and follow-up scope

---

## Solution for Issue #1: Implement Journal Sync

**Status:** ✅ Completed — journal entries now read/write directly against Supabase with an in-memory cache (no on-device persistence).

### Overview
Create `SupabaseJournalRepository` following the same pattern as competitions/venues.

### Components Needed

1. **API Layer** (`SupabaseJournalAPI.swift`):
   - `upsertAssessment()` - sync local entry to remote
   - `fetchAssessments()` - pull remote entries updated after cursor
   - `deleteAssessment()` - remove from remote

2. **Repository Layer** (`SupabaseJournalRepository.swift`):
   - Wrap `SwiftDataJournalStore`
   - Implement `JournalEntryStoring` protocol
   - Add sync backlog for offline resilience
   - Handle auth state changes (clear on sign-out)

3. **Environment Wiring** (`RefZoneiOSApp.swift:96`):
   ```swift
   let swiftJournalStore = SwiftDataJournalStore(container: container, auth: authController)
   let jStore: JournalEntryStoring = SupabaseJournalRepository(
       store: swiftJournalStore,
       authStateProvider: authController
   )
   ```

### Key Considerations
- Follow same offline-first pattern as match history
- Use `match_assessments` table (already migrated)
- Convert `JournalEntry.ownerId` (String) ⇄ Supabase UUID on the way in/out; reject/repair corrupted values so inserts don't fail.
- Implement retry backlog for failed syncs
- Clear local data on sign-out

**Estimated Effort**: 6-8 hours

---

## Solution for Issue #3: Library Entity FK Validation

### Overview
Add pre-flight validation in `MatchSetupView` to ensure selected library entities are synced before starting match.

### Approach A: Sync Validation in Match Setup (Recommended)

**File**: `MatchSetupView.swift:296-320`

Add state:
```swift
@State private var isSyncingLibraryEntities = false
@State private var syncValidationError: String?
@State private var librarySyncStatus: LibraryEntitySyncStatus = .unknown

enum LibraryEntitySyncStatus {
    case unknown
    case checking
    case allSynced
    case partialSync(missing: [String])
    case syncFailed(error: String)
}
```

Add validation on selection change:
```swift
.onChange(of: selectedHomeTeam) { _ in validateLibrarySync() }
.onChange(of: selectedCompetition) { _ in validateLibrarySync() }
.onChange(of: selectedVenue) { _ in validateLibrarySync() }

private func validateLibrarySync() {
    Task {
        librarySyncStatus = .checking
        var missingSyncs: [String] = []

        if let team = selectedHomeTeam, !team.isSyncedToRemote {
            missingSyncs.append("Home Team (\(team.name))")
        }
        // ... check away team, competition, venue

        librarySyncStatus = missingSyncs.isEmpty ? .allSynced : .partialSync(missing: missingSyncs)
    }
}
```

Pre-flight sync before match start:
```swift
private func startMatch() {
    Task {
        do {
            let syncResult = try await syncLibraryEntitiesBeforeMatch()  // ✅ Force sync selected entities using new async API
            guard syncResult.isSatisfied else {
                syncValidationError = syncResult.message
                return
            }

            // Now safe to create match with FKs
            var match = Match(...)
            match.competitionId = selectedCompetition?.id
            // ...
        } catch {
            syncValidationError = error.localizedDescription
        }
    }
}
```

**Required Protocol Changes**:
Add to library storing protocols:
```swift
protocol TeamLibraryStoring {
    /// Blocks until the specified records have been confirmed as synced remotely
    func ensureRemoteSync(for ids: Set<UUID>, timeout: Duration) async throws -> LibrarySyncResult
    // ... existing methods
}
```

(`LibrarySyncResult` can report `.synced`, `.timedOut(pending:)`, `.failed(errors:)` so callers can decide whether to continue.)

`syncLibraryEntitiesBeforeMatch()` should return that `LibrarySyncResult`, allowing the UI to present actionable messaging (e.g. "Home Team still syncing from cloud" vs. hard failure).

Add a lightweight helper on `LibrarySyncResult` (e.g. `var isSatisfied: Bool` plus `var message: String`) so call sites stay terse.

**Repository Implementation Notes**:
- Extend `SupabaseTeamLibraryRepository`/`SupabaseCompetitionLibraryRepository`/`SupabaseVenueLibraryRepository` to keep a dictionary of `CheckedContinuation`s keyed by record ID.
- Resolve the continuation in `performRemotePush` when Supabase confirms the write (or when an error occurs).
- When the repository enqueues a push it should also return the Task handle to the caller so `ensureRemoteSync` can await completion instead of polling `needsRemoteSync`.
- Apply the same mechanism to deletions if Match Setup ever depends on them.

Add to models:
```swift
extension TeamRecord {
    var isSyncedToRemote: Bool {
        return !needsRemoteSync && remoteUpdatedAt != nil
    }
}
```

**Estimated Effort**: 10-12 hours (includes repository continuations + UI updates)

---

### Approach B: Graceful Degradation (Fallback)

If sync validation is too complex, add FK existence check in `SupabaseMatchHistoryRepository`:

```swift
private func makeMatchBundleRequest(...) -> MatchBundleRequest? {
    // Validate FKs exist remotely before including
    let competitionId = await validateCompetitionExists(match.competitionId)
        ? match.competitionId
        : nil

    let matchPayload = MatchBundleRequest.MatchPayload(
        competitionId: competitionId,  // Nullable if not synced
        competitionName: match.competitionName,  // Always preserve name
        // ...
    )
}

private func validateCompetitionExists(_ id: UUID?) async -> Bool {
    guard let id else { return false }
    // Quick check in Supabase
    // ...
}
```

**Estimated Effort**: 4-5 hours

---

## Testing Strategy

### For Competition/Venue Pull (Issue #2)
1. ✅ Create competition in Supabase directly → confirmed exists
2. ❌ Launch app signed in → verify pull fires → **CURRENTLY FAILING**
3. ❌ Open Settings → Library → Competitions → verify appears → **CURRENTLY EMPTY**
4. ❌ Match Setup → Competition picker → verify appears → **CURRENTLY EMPTY**
5. After fix: verify all above work
6. Sign in on second device → verify pull succeeds

### For Journal Sync (Issue #1)
1. Create journal entry offline → verify backlog queues
2. Sign in → verify entry syncs
3. Sign in on device B → verify entry pulled
4. Modify on device A → verify syncs to B
5. Delete → verify propagates

### For FK Validation (Issue #3)
1. Create competition locally → immediately use in match → verify sync waits
2. Network offline → verify match saves with name but null FK
3. Network returns → verify reconciliation backfills FK
4. Multi-device: create on device A → use on device B → verify works

---

## Database Verification Queries

```sql
-- Verify competitions exist (✅ passing)
SELECT id, name, owner_id, created_at, updated_at 
FROM competitions 
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY created_at DESC;

-- Verify venues exist (✅ passing)
SELECT id, name, city, country, owner_id, created_at, updated_at 
FROM venues 
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY created_at DESC;

-- Verify journal entries (after fix)
SELECT ma.id, ma.match_id, ma.rating, m.home_team_name, m.away_team_name, ma.created_at
FROM match_assessments ma
JOIN matches m ON ma.match_id = m.id
WHERE ma.owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY ma.created_at DESC LIMIT 10;

-- Verify match FK integrity
SELECT 
    m.id,
    m.home_team_name,
    m.competition_name,
    m.venue_name,
    m.competition_id,
    m.venue_id,
    CASE WHEN m.competition_id IS NOT NULL THEN 'Linked' ELSE 'Unlinked' END as comp_status,
    CASE WHEN m.venue_id IS NOT NULL THEN 'Linked' ELSE 'Unlinked' END as venue_status
FROM matches m
WHERE m.owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
  AND m.status = 'completed'
ORDER BY m.completed_at DESC LIMIT 20;
```

---

## Conclusion

**Key Findings**:
- Issue #2 (competition/venue pull) is the **immediate blocker**
- Data exists in Supabase but isn't being pulled to local store
- This is **simpler to fix** than the original FK validation problem
- Fixing #2 will unblock user workflow and allow testing of #3

**Updated Timeline**:

- **Phase 1**: Fix competition/venue pull (Issue #2)
- **Phase 2**: Implement journal sync (Issue #1)
- **Phase 3**: Add FK validation (Issue #3)
- **Phase 4**: Testing, reconciliation, polish

Once Issue #2 is resolved, users will be able to select competitions/venues when creating matches, and we can then implement FK validation safeguards.

**Immediate Action Item (pre-implementation)**:
- Instrument `SupabaseCompetitionLibraryRepository` and `SupabaseVenueLibraryRepository` with the logging/metrics outlined above, then capture simulator logs against the current Supabase seed to confirm the pull path behaviour before shipping code changes.


### Updates
- Phase 1 (Library sync fixes) completed
- Phase 2 (Journal Supabase integration) completed
