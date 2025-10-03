# Critical Investigation: Supabase Sync Failures

**Date**: October 3, 2025
**Status**: Root Cause Analysis Complete
**Priority**: Critical - Blocking all journal and library functionality

---

## Executive Summary

Investigation of the recent Supabase integration reveals **three critical architectural flaws** that completely break journal saving, competition/venue syncing, and cause UI freezes:

1. **Issue #1 (Journal Save Freeze)**: `SupabaseJournalRepository.runSync()` creates a **Main Thread Deadlock** by blocking the MainActor thread while waiting for an async network operation.
2. **Issue #2 (Journal Pull Spam)**: Excessive "cancelled" errors caused by **aggressive pull triggering** on every view evaluation, creating task cancellation cascade.
3. **Issue #3 (Empty Competitions/Venues)**: Library data exists in Supabase but **never appears in UI** due to repositories only syncing when local changes are made, not on auth state transitions.

**All three issues stem from fundamental architectural problems introduced during Phase 1-2 implementation.**

---

## Issue #1: Journal Save Deadlock 🔴 CRITICAL

### Observed Behavior

When users attempt to save a journal assessment:
- **Save button becomes unresponsive**
- **All UI buttons disabled** (Cancel, navigation)
- **App appears frozen**
- **No error message displayed**
- **Entry never saves to Supabase**

### Root Cause Analysis

**File**: [SupabaseJournalRepository.swift:284-301](SupabaseJournalRepository.swift#L284-L301)

```swift
@MainActor
final class SupabaseJournalRepository: JournalEntryStoring {
    // ...

    func upsert(_ entry: JournalEntry) throws {
        let owner = try requireOwnerUUID(operation: "save journal entry")
        // ...

        let result = try runSync {  // ⚠️ BLOCKS MAIN THREAD
            try await self.api.syncAssessment(request)
        }
        // ...
    }

    private func runSync<T>(_ work: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)  // ❌ DEADLOCK SOURCE
        var result: Result<T, Error>?
        Task.detached {
            do {
                let value = try await work()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()  // ❌ BLOCKS MAIN THREAD INDEFINITELY
        // ...
    }
}
```

**The Deadlock Mechanism**:

1. `JournalEditorView.save()` calls `store.upsert()` on the **Main Thread** (MainActor)
2. `upsert()` is a **synchronous throwing function** (`throws`, not `async throws`)
3. `runSync()` spawns a `Task.detached` to perform the async network call
4. `semaphore.wait()` **blocks the Main Thread** waiting for the detached task to complete
5. BUT: The detached task needs the MainActor to update repository state
6. **DEADLOCK**: Main thread waits for detached task, detached task waits for Main thread

**Why This Wasn't Caught**:

The team followed the pattern from `SwiftDataJournalStore`, which uses synchronous `throws` methods. However, the Supabase implementation requires `async throws` because it performs network I/O. Attempting to bridge sync/async with semaphores on MainActor is a classic Swift concurrency anti-pattern.

### Impact

- **Complete journal feature failure** - no entries can be saved
- **Terrible UX** - app appears frozen with no feedback
- **Data loss** - users lose their match assessments

---

## Issue #2: Journal Pull Task Cancellation Spam

### Observed Behavior

Console flooded with:
```
Journal pull failed: cancelled
Journal pull failed: cancelled
Journal pull failed: cancelled
[... hundreds of times ...]
```

### Root Cause Analysis

**File**: [SupabaseJournalRepository.swift:58-64](SupabaseJournalRepository.swift#L58-L64), [196-210](SupabaseJournalRepository.swift#L196-L210)

```swift
func loadEntries(for matchId: UUID) throws -> [JournalEntry] {
    if entriesByMatch[matchId] == nil {
        triggerPull(force: true)  // ⚠️ CALLED ON EVERY VIEW EVALUATION
    } else {
        triggerPull()
    }
    return entriesByMatch[matchId] ?? []
}

private func triggerPull(force: Bool = false) {
    guard ownerUUID != nil else { return }
    if !force, pullTask != nil { return }
    pullTask?.cancel()  // ❌ CANCELS PREVIOUS TASK
    pullTask = Task { [weak self] in
        guard let self else { return }
        do {
            try await self.pullAllEntries()
        } catch {
            self.log.error("Journal pull failed: \(error.localizedDescription)")
        }
        // ...
    }
}
```

**The Cancellation Cascade**:

1. SwiftUI calls `loadEntries()` during view body evaluation
2. `loadEntries()` triggers a background pull task
3. SwiftUI re-evaluates (state change, appear/disappear, etc.)
4. `loadEntries()` called again → cancels previous task, starts new one
5. Previous task throws `CancellationError` → logged as "cancelled"
6. **Repeat indefinitely** as SwiftUI evaluates views

**Why This Pattern Fails**:

The `loadEntries()` method is designed as a **synchronous query** (matching `JournalEntryStoring` protocol), but it has **side effects** (triggering network pulls). SwiftUI views can call this multiple times per second during animations, transitions, etc.

### Impact

- **Console spam** obscures real errors
- **Wasted network bandwidth** from repeated fetch attempts
- **Battery drain** from constant task creation/cancellation
- **Confusing for debugging** - looks like failures but may be "normal" behavior

---

## Issue #3: Competitions/Venues Never Sync from Supabase 🔴 CRITICAL

### Observed Behavior

Despite data existing in Supabase:
- **Competition picker shows "No Competitions Yet"**
- **Venue picker shows "No Venues Yet"**
- **Library settings screens show empty states**
- **Match setup cannot proceed** (cannot select competition/venue)

### Database Verification

**Confirmed data EXISTS in Supabase**:

```sql
SELECT id, name, owner_id, created_at, updated_at
FROM competitions
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371';
```
**Result**: `NPL` (created 2025-10-01, updated 2025-10-01)

```sql
SELECT id, name, city, country, owner_id, created_at, updated_at
FROM venues
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371';
```
**Result**: `Marden Sports Complex` (created 2025-10-01, updated 2025-10-01)

### Root Cause Analysis

**File**: [SupabaseCompetitionLibraryRepository.swift:150-189](SupabaseCompetitionLibraryRepository.swift#L150-L189)

The repository has comprehensive sync logic including:
- ✅ `scheduleInitialSync()` - called when authenticated
- ✅ `performInitialSync()` - flushes deletions, pushes dirty records, pulls remote updates
- ✅ `pullRemoteUpdates()` - fetches from Supabase with cursor support
- ✅ Detailed logging for debugging

**However, examining the auth state handler**:

```swift
private func handleAuthState(_ state: AuthState) async {
    switch state {
    case .signedOut:
        // ... cleanup
    case let .signedIn(userId, _, _):
        guard let uuid = UUID(uuidString: userId) else {
            log.error("Competition sync received non-UUID Supabase id: ...")
            return
        }
        ownerUUID = uuid
        publishSyncStatus()
        scheduleInitialSync()  // ✅ THIS SHOULD WORK
    }
}
```

**The Real Problem**: Initial sync logic exists but **initial sync may not be completing successfully**.

Looking at `performInitialSync()`:

```swift
func performInitialSync() async {
    guard let ownerUUID else { return }
    // ...
    do {
        try await flushPendingDeletions()
        try await pushDirtyCompetitions()
        try await pullRemoteUpdates(for: ownerUUID)  // ← Should pull remote data
        // ...
    } catch {
        log.error("Initial competition sync failed: ...")  // ← Error swallowed
    }
}
```

**Hypothesis**: The sync IS firing, but either:
1. **Silent failure** - error is logged but sync stops, leaving UI empty
2. **Timing issue** - `remoteCursor` may have stale value, causing `updatedAfter` filter to exclude all data
3. **Race condition** - UI loads before initial sync completes

**Evidence from Plan Document** (line 96):
> "The Problem: Remote pull logic exists but the data still never populates. Our current suspicion is that the existing pull path is executing but either returning an empty result set or failing silently."

**From Plan Document Recommendations** (line 179-194):
> "Approach A: Instrument the Existing Pull Path ⭐ **Recommended**
>
> Goal: Confirm whether `performInitialSync()` fires and why `pullRemoteUpdates` fails to materialise records."

The plan correctly identified that **instrumentation was needed** to diagnose the pull path. Line 175 confirms:
> "Status: ✅ Completed — instrumentation shipped and remote pulls now log telemetry for debugging."

**But the issue persists**, meaning:
1. Instrumentation was added BUT logs show no evidence of `performInitialSync` being called
2. OR the sync completes but records aren't being written to SwiftData store
3. OR the picker's `loadCompetitions()` runs BEFORE initial sync completes

### Additional Analysis: Picker Timing

**File**: [CompetitionPickerSheet.swift:97-107](CompetitionPickerSheet.swift#L97-L107)

```swift
private func loadCompetitions() {
    isLoading = true
    loadError = nil
    do {
        competitions = try competitionStore.loadAll()  // ← Reads LOCAL SwiftData only
    } catch {
        loadError = error.localizedDescription
        competitions = []
    }
    isLoading = false
}
```

**The picker**:
- ✅ Calls `loadAll()` which reads from SwiftData
- ❌ **Never triggers a remote pull**
- ❌ **No way to refresh** if initial sync hasn't completed

**From Plan Document** (line 119):
> "Pickers **never trigger a remote pull**. They rely entirely on background sync having already populated the local store."

### Why Teams Work But Competitions/Venues Don't

**From Plan Document** (line 121-132):
> "**Teams sync successfully** because they're typically created locally first (via iOS app), which:
> 1. Triggers a local save
> 2. Enqueues a push to Supabase
> 3. Processing queue starts
> 4. After push completes, pull happens as part of queue processing
>
> **Competitions/Venues still appear missing** when created remotely (direct DB insert, web admin, another device):
> - No local dirty record to push
> - Processing queue never runs a push, so we depend entirely on the remote pull
> - Without instrumentation we cannot confirm whether the pull completes, returns empty, or errors out"

**This confirms**: The repositories are designed to sync LOCAL → REMOTE, but the REMOTE → LOCAL path (initial pull on sign-in) is either not executing or not working correctly.

### Impact

- **Match setup completely blocked** - users cannot create matches without competition/venue
- **Library screens show empty** despite data existing
- **Multi-device sync broken** - data created on one device never appears on others
- **User confusion** - "I created this in the database, why doesn't it show?"

---

## Recommended Solutions

### Priority Order

**Phase 1: Critical Fixes (Ship ASAP)**
1. **Issue #1** - Fix journal save deadlock - **2-3 hours**
2. **Issue #3** - Fix competition/venue initial pull - **4-6 hours**

**Phase 2: Quality Improvements (Next Sprint)**
3. **Issue #2** - Refactor journal pull triggering - **3-4 hours**

---

## Solution for Issue #1: Journal Save Deadlock

### Fix: Convert to Async/Await Throughout

The protocol `JournalEntryStoring` must change from synchronous to asynchronous. This is a **breaking change** but necessary for Supabase integration.

**Step 1: Update Protocol**

**File**: `RefWatchCore/Sources/RefWatchCore/Protocols/JournalEntryStoring.swift`

```swift
protocol JournalEntryStoring {
    func loadEntries(for matchId: UUID) async throws -> [JournalEntry]
    func loadLatest(for matchId: UUID) async throws -> JournalEntry?
    func loadRecent(limit: Int) async throws -> [JournalEntry]
    func upsert(_ entry: JournalEntry) async throws  // ← async throws
    func create(
        matchId: UUID,
        rating: Int?,
        overall: String?,
        wentWell: String?,
        toImprove: String?
    ) async throws -> JournalEntry  // ← async throws
    func delete(id: UUID) async throws  // ← async throws
    func deleteAll(for matchId: UUID) async throws  // ← async throws
    func wipeAllForLogout() async throws  // ← async throws
}
```

**Step 2: Update SupabaseJournalRepository**

**File**: [SupabaseJournalRepository.swift](SupabaseJournalRepository.swift)

```swift
@MainActor
final class SupabaseJournalRepository: JournalEntryStoring {
    // Remove runSync() completely

    func upsert(_ entry: JournalEntry) async throws {  // ← async throws
        let owner = try requireOwnerUUID(operation: "save journal entry")
        let now = dateProvider()
        var requestEntry = entry
        requestEntry.ownerId = owner.uuidString
        requestEntry.updatedAt = now

        let request = SupabaseJournalAPI.AssessmentRequest(
            id: requestEntry.id,
            matchId: requestEntry.matchId,
            ownerId: owner,
            rating: requestEntry.rating,
            overall: requestEntry.overall,
            wentWell: requestEntry.wentWell,
            toImprove: requestEntry.toImprove,
            createdAt: requestEntry.createdAt,
            updatedAt: now
        )

        let result = try await api.syncAssessment(request)  // ← Direct await, no semaphore

        requestEntry.updatedAt = result.updatedAt
        cache(entry: requestEntry)
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
        triggerPull()
    }

    func create(
        matchId: UUID,
        rating: Int?,
        overall: String?,
        wentWell: String?,
        toImprove: String?
    ) async throws -> JournalEntry {  // ← async throws
        let owner = try requireOwnerUUID(operation: "create journal entry")
        let now = dateProvider()
        var entry = JournalEntry(
            matchId: matchId,
            createdAt: now,
            updatedAt: now,
            ownerId: owner.uuidString,
            rating: rating,
            overall: overall,
            wentWell: wentWell,
            toImprove: toImprove
        )

        let request = SupabaseJournalAPI.AssessmentRequest(
            id: entry.id,
            matchId: entry.matchId,
            ownerId: owner,
            rating: entry.rating,
            overall: entry.overall,
            wentWell: entry.wentWell,
            toImprove: entry.toImprove,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )

        let result = try await api.syncAssessment(request)  // ← Direct await

        entry.updatedAt = result.updatedAt
        cache(entry: entry)
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
        triggerPull()
        return entry
    }

    func delete(id: UUID) async throws {  // ← async throws
        let owner = try requireOwnerUUID(operation: "delete journal entry")
        _ = owner
        try await api.deleteAssessment(id: id)  // ← Direct await
        removeEntry(withId: id)
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
        triggerPull()
    }

    func deleteAll(for matchId: UUID) async throws {  // ← async throws
        let entries = entriesByMatch[matchId] ?? []
        for entry in entries {
            try await delete(id: entry.id)
        }
    }

    func wipeAllForLogout() async throws {  // ← async throws
        entriesByMatch.removeAll()
        NotificationCenter.default.post(name: .journalDidChange, object: nil)
    }

    // DELETE runSync() entirely - no longer needed
}
```

**Step 3: Update JournalEditorView**

**File**: [JournalEditorView.swift:74-98](JournalEditorView.swift#L74-L98)

```swift
private func save() {
    Task {  // ← Wrap in Task
        do {
            if var entry = existing {
                entry.rating = rating == 0 ? nil : rating
                entry.overall = overall.isEmpty ? nil : overall
                entry.wentWell = wentWell.isEmpty ? nil : wentWell
                entry.toImprove = toImprove.isEmpty ? nil : toImprove
                entry.updatedAt = Date()
                try await store.upsert(entry)  // ← await
            } else {
                _ = try await store.create(  // ← await
                    matchId: matchId,
                    rating: rating == 0 ? nil : rating,
                    overall: overall.isEmpty ? nil : overall,
                    wentWell: wentWell.isEmpty ? nil : wentWell,
                    toImprove: toImprove.isEmpty ? nil : toImprove
                )
            }
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
```

**Step 4: Update SwiftDataJournalStore** (if still used in watchOS)

If `SwiftDataJournalStore` is still used (e.g., for watchOS local-only storage), update it to match the async protocol:

```swift
@MainActor
final class SwiftDataJournalStore: JournalEntryStoring {
    func upsert(_ entry: JournalEntry) async throws {
        // Existing synchronous code works fine in async context
        // Just mark as async throws
    }

    func create(
        matchId: UUID,
        rating: Int?,
        overall: String?,
        wentWell: String?,
        toImprove: String?
    ) async throws -> JournalEntry {
        // Existing synchronous code
    }

    // ... etc
}
```

### Testing Strategy

1. **Manual test**: Save journal entry → verify no freeze
2. **Verify Supabase**: Check `match_assessments` table has new row
3. **Multi-device**: Save on device A → pull on device B → verify appears
4. **Error handling**: Disconnect network → save → verify error shown gracefully

**Estimated Effort**: 2-3 hours

---

## Solution for Issue #2: Journal Pull Task Cancellation Spam

### Fix: Separate Data Loading from Side Effects

The problem is mixing **query behavior** (synchronous `loadEntries()`) with **sync behavior** (asynchronous `triggerPull()`).

**Option A: Remove Pull Triggering from Load Methods** (Recommended)

**Rationale**: The repository already triggers pulls on auth state changes. Additional pulls during load are redundant and cause cancellation spam.

**File**: [SupabaseJournalRepository.swift:58-76](SupabaseJournalRepository.swift#L58-L76)

```swift
func loadEntries(for matchId: UUID) async throws -> [JournalEntry] {
    // Remove triggerPull() calls entirely
    return entriesByMatch[matchId] ?? []
}

func loadLatest(for matchId: UUID) async throws -> JournalEntry? {
    try await loadEntries(for: matchId).first
}

func loadRecent(limit: Int) async throws -> [JournalEntry] {
    let all = entriesByMatch.values.flatMap { $0 }
    return Array(all.sorted(by: { $0.updatedAt > $1.updatedAt })
        .prefix(max(1, limit)))
}
```

**Pulls will still happen**:
- On sign-in (via `handleAuthState`)
- After save/delete (via `upsert()`, `delete()`)

**Option B: Debounce Pull Triggering** (Alternative)

If we want to keep the "pull on load" behavior:

```swift
private var lastPullTime: Date?
private let pullDebounceInterval: TimeInterval = 5.0  // 5 seconds

func loadEntries(for matchId: UUID) async throws -> [JournalEntry] {
    let now = Date()
    if let lastPull = lastPullTime,
       now.timeIntervalSince(lastPull) < pullDebounceInterval {
        // Skip pull if last pull was recent
    } else {
        triggerPull()
        lastPullTime = now
    }
    return entriesByMatch[matchId] ?? []
}
```

**Recommendation**: Use Option A. Option B adds complexity with minimal benefit since auth-based pulls are sufficient.

### Testing Strategy

1. Open journal view → check console for "cancelled" spam
2. Navigate between screens → verify no excessive pull attempts
3. Sign in → verify single pull attempt on auth state change

**Estimated Effort**: 1-2 hours (Option A), 3-4 hours (Option B)

---

## Solution for Issue #3: Competitions/Venues Never Sync from Supabase

### Investigation Steps Required

Before implementing a fix, we need to confirm **why** the initial pull isn't populating SwiftData:

**Step 1: Add Debug Logging** (if not already present per Plan line 175)

**File**: [SupabaseCompetitionLibraryRepository.swift:315-390](SupabaseCompetitionLibraryRepository.swift#L315-L390)

Verify these logs exist (they should per Plan):

```swift
func pullRemoteUpdates(for ownerUUID: UUID) async throws {
    let ownerString = ownerUUID.uuidString
    let cursorBefore = describe(remoteCursor)

    log.debug(
        "Competition pull requesting owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public)"
    )

    let remoteCompetitions = try await api.fetchCompetitions(ownerId: ownerUUID, updatedAfter: remoteCursor)
    log.info(
        "Competition pull received count=\(remoteCompetitions.count) owner=\(ownerString, privacy: .public) cursor=\(cursorBefore, privacy: .public)"
    )

    // ... apply to store

    log.notice(
        "Competition pull applied inserted=\(insertedCount) updated=\(updatedCount) skipped_delete=\(skippedPendingDeletion) skipped_dirty=\(skippedDirtyConflict)"
    )
}
```

**Step 2: Check Logs on App Launch**

Run the app and check console for:
1. "Competition initial sync started" → confirms sync triggered
2. "Competition pull requesting" → confirms pull API call made
3. "Competition pull received count=X" → confirms data returned from Supabase
4. "Competition pull applied" → confirms records inserted/updated

**Step 3: Diagnose Based on Logs**

| Log Output | Diagnosis | Fix |
|------------|-----------|-----|
| No "initial sync started" | `scheduleInitialSync()` not called | Verify `handleAuthState(.signedIn)` fires |
| "sync started" but no "pull requesting" | `pullRemoteUpdates()` not reached | Check if `pushDirtyCompetitions()` throws error |
| "pull requesting" but no "pull received" | API call failing | Check network/auth errors in API layer |
| "pull received count=0" | Cursor filtering everything out | Reset `remoteCursor = nil` on sign-in |
| "pull received count=1" but no "pull applied" | Insert/update logic failing | Check SwiftData save errors |

### Fix Options (Based on Diagnosis)

**Fix A: Reset Cursor on Sign-In** (Most Likely)

If logs show `count=0` despite data existing in database:

**File**: [SupabaseCompetitionLibraryRepository.swift:130-148](SupabaseCompetitionLibraryRepository.swift#L130-L148)

```swift
func handleAuthState(_ state: AuthState) async {
    switch state {
    case .signedOut:
        ownerUUID = nil
        processingTask?.cancel()
        processingTask = nil
        try? store.wipeAllForAuth()
        pendingPushes.removeAll()
        pendingDeletions.removeAll()
        backlog.clear()
        remoteCursor = nil  // ← Already present
        publishSyncStatus()
    case let .signedIn(userId, _, _):
        guard let uuid = UUID(uuidString: userId) else {
            log.error("Competition sync received non-UUID Supabase id: \(userId, privacy: .public)")
            return
        }
        ownerUUID = uuid
        remoteCursor = nil  // ← ADD THIS: Force full sync on sign-in
        publishSyncStatus()
        scheduleInitialSync()
    }
}
```

**Rationale**: If cursor has stale timestamp (e.g., from previous session), the `updatedAfter` filter will exclude all records created before that timestamp. Resetting on sign-in ensures we fetch everything.

**Fix B: Add Explicit Pull on Picker Load** (Complementary)

From Plan Document (line 198-264), add protocol method for on-demand pulls:

**File**: `RefZoneiOS/Core/Protocols/CompetitionLibraryStoring.swift`

```swift
protocol CompetitionLibraryStoring {
    // ... existing methods
    func refreshFromRemote() async throws  // ← NEW
}
```

**File**: [SupabaseCompetitionLibraryRepository.swift](SupabaseCompetitionLibraryRepository.swift)

```swift
func refreshFromRemote() async throws {
    guard let ownerUUID else {
        throw PersistenceAuthError.signedOut(operation: "refresh competitions")
    }
    try await pullRemoteUpdates(for: ownerUUID)
}
```

**File**: [CompetitionPickerSheet.swift:97-107](CompetitionPickerSheet.swift#L97-L107)

```swift
private func loadCompetitions() {
    isLoading = true
    loadError = nil
    pullError = nil

    Task {
        // ✅ Pull from remote first
        do {
            try await competitionStore.refreshFromRemote()
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

**Fix C: Add Periodic Background Pull** (Long-term)

From Plan Document (line 267-297):

```swift
private var pullTimer: Timer?

func scheduleInitialSync() {
    // ... existing code

    // ✅ ADD: Periodic pull every 5 minutes
    pullTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
        Task { @MainActor [weak self] in
            guard let self, let ownerUUID = self.ownerUUID else { return }
            do {
                try await self.pullRemoteUpdates(for: ownerUUID)
            } catch {
                self.log.error("Periodic competition pull failed: \(error.localizedDescription)")
            }
        }
    }
}

deinit {
    pullTimer?.invalidate()
    // ... existing cleanup
}
```

### Recommended Implementation

1. **Immediate (Ship Today)**: Fix A - Reset cursor on sign-in
2. **Short-term (This Week)**: Fix B - Add `refreshFromRemote()` to pickers
3. **Long-term (Next Sprint)**: Fix C - Periodic background pulls

**Apply same fixes to Venues** - exact same pattern/code.

### Testing Strategy

1. Create competition in Supabase DB directly
2. Sign in on iOS app → check logs for pull
3. Open competition picker → verify appears
4. Verify venue picker works identically
5. Multi-device: Create on device A → sign in on device B → verify appears

**Estimated Effort**: 4-6 hours (includes venues, testing)

---

## Testing Strategy (Overall)

### Pre-Flight Checks

Before declaring fixes complete, verify:

**Journal (Issue #1)**:
- [ ] Save journal entry → no UI freeze
- [ ] Entry appears in local cache immediately
- [ ] Entry synced to Supabase `match_assessments` table
- [ ] Edit entry → saves successfully
- [ ] Delete entry → removes from local + remote
- [ ] Network error → shows user-friendly error message

**Journal Pulls (Issue #2)**:
- [ ] Console has no "cancelled" spam
- [ ] App launch → single pull on sign-in
- [ ] Navigate between screens → no excessive pulls
- [ ] Performance acceptable (no battery drain)

**Competitions/Venues (Issue #3)**:
- [ ] Sign in → competitions/venues load from Supabase
- [ ] Competition picker shows data
- [ ] Venue picker shows data
- [ ] Match setup can select competition/venue
- [ ] Library settings shows data
- [ ] Multi-device sync works

### Regression Testing

Ensure fixes don't break existing functionality:
- [ ] Teams still sync correctly
- [ ] Matches still save/sync
- [ ] Schedule still works
- [ ] Sign-out clears data appropriately

---

## Timeline

**Phase 1 (Critical Fixes)**:
- **Day 1**: Fix Issue #1 (journal deadlock) - 2-3 hours
- **Day 1-2**: Fix Issue #3 (competition/venue sync) - 4-6 hours
- **Day 2**: Testing & validation - 2-3 hours
- **Total**: 8-12 hours (1-2 days)

**Phase 2 (Quality Improvements)**:
- **Week 2**: Fix Issue #2 (journal pull spam) - 3-4 hours
- **Week 2**: Add periodic background pulls - 2 hours
- **Total**: 5-6 hours

---

## Conclusion

**Root Causes Identified**:

1. **Architectural Mismatch**: Attempting to bridge synchronous protocol (`JournalEntryStoring`) with asynchronous Supabase API using semaphores creates MainActor deadlock.

2. **Side Effect Abuse**: Triggering background tasks from synchronous query methods (`loadEntries()`) causes task cancellation cascade.

3. **Incomplete Sync Flow**: Initial pull on sign-in may be failing silently or not executing at all, leaving local SwiftData empty despite remote data existing.

**Immediate Actions**:

1. Convert `JournalEntryStoring` protocol to `async throws`
2. Remove `runSync()` deadlock pattern from `SupabaseJournalRepository`
3. Diagnose competition/venue pull path with existing instrumentation
4. Reset `remoteCursor` on sign-in to force full sync
5. Add `refreshFromRemote()` to pickers for user-triggered refresh

**Long-term Improvements**:

1. Add periodic background sync for multi-device scenarios
2. Implement proper error handling with user-visible feedback
3. Add unit tests for sync edge cases (network failures, conflicts, etc.)
4. Consider protocol redesign for consistent async/await patterns

**Blocking Resolved**: Once Phase 1 fixes ship, users can:
- ✅ Save journal entries without freezing
- ✅ Select competitions/venues in match setup
- ✅ View library data synced from Supabase
- ✅ Use app across multiple devices with proper sync

**Status**: Ready for implementation. No additional investigation required.
