# Implementation Plan: iOS Library Features & Match History Display

**Status**: Completed
**Created**: 2025-09-30
**Last Updated**: 2025-10-02

## Progress Summary

- ✅ **Phase 1**: Match History Display - COMPLETED
- ✅ **Phase 2**: Competitions Library - COMPLETED
- ✅ **Phase 3**: Venues Library - COMPLETED
- ✅ **Phase 4**: Team Selection Integration - COMPLETED
- ✅ **Phase 5**: Competition/Venue Match Setup - COMPLETED

## Overview

This plan addresses three critical user-facing features that connect the iOS app to the Supabase database:

1. **Display saved matches from database** - Users can save matches but cannot view them
2. **Competitions & Venues library** - Currently shows "coming soon" placeholders
3. **Team selection from library** - Match setup should allow selecting saved teams

## Context Analysis

### Current State

**Match History (Feature 1)**
- ✅ `SupabaseMatchHistoryRepository` successfully pulls matches from database
- ✅ `SwiftDataMatchHistoryStore` stores matches locally
- ✅ Database contains completed matches (verified: 1 match found in `matches` table)
- ❌ `MatchHistoryView` loads from local store but repository isn't properly hydrating it
- **Root Issue**: The repository pulls remote matches in `pullRemoteUpdates()` but the UI's `MatchHistoryView` only shows what's in the local SwiftData store

**Teams Library (Feature 3)**
- ✅ `SupabaseTeamLibraryRepository` syncs teams bidirectionally
- ✅ Database contains teams (verified: 4 teams found in `teams` table)
- ✅ `TeamsListView` displays teams from store
- ❌ `MatchSetupView` uses manual text entry instead of team picker
- **Root Issue**: No UI integration for team selection in match setup

**Competitions & Venues (Feature 2)**
- ❌ No Swift models for Competition or Venue entities
- ❌ No SwiftData persistence layer
- ❌ No Supabase API client
- ❌ No repository implementation
- ✅ Database tables exist (`competitions`, `venues`) but are empty
- ✅ Database schema is well-defined with proper relationships
- **Root Issue**: Complete feature gap - needs full stack implementation

## Implementation Plan

### Phase 1: Fix Match History Display (Priority: Critical) ✅ COMPLETED

**Problem**: Remote matches are pulled but not appearing in UI.

**Root Cause Hypothesis**: `SupabaseMatchHistoryRepository.pullRemoteUpdates()` inserts/merges into SwiftData but `MatchHistoryView` may be loading before initial sync completes, or sync isn't triggering properly.

#### Pre-Implementation: Diagnostic Phase

**Before making changes**, confirm the root cause with instrumentation:

1. **Add temporary debug logging** to `SupabaseMatchHistoryRepository`:
   ```swift
   // In pullRemoteUpdates()
   #if DEBUG
   log.debug("Match history pull started for owner=\(ownerUUID.uuidString)")
   log.debug("Fetched \(remoteBundles.count) remote bundles")
   log.debug("Posting .matchHistoryDidChange notification")
   #endif
   ```

2. **Reproduce the issue** with existing match:
   - Match ID: `2f932df8-eda5-4b09-bf7c-e8cfecf8f7d0`
   - Open app → navigate to History tab
   - Check console logs for sync flow
   - Verify notification fires: `NotificationCenter.default.post(name: .matchHistoryDidChange)`

3. **Document findings** before proceeding with solution

#### Solution Implementation

**Files to modify**:
- `RefZoneiOS/Features/Matches/Views/MatchesTabView.swift` - Add sync trigger on appear
- `RefZoneiOS/Core/Platform/Supabase/SupabaseMatchHistoryRepository.swift` - Temporary diagnostic logging
- `RefZoneiOS/Features/Match/MatchHistory/MatchHistoryView.swift` - Loading state + error display
- `RefZoneiOS/Core/Diagnostics/SyncDiagnosticsCenter.swift` - Integration for error surfacing

**Implementation Steps**:

1. **Pass `MatchHistorySyncControlling` down view hierarchy**:
   ```swift
   // In MainTabView or parent container
   let historyStore = matchHistoryRepository // Already conforms to MatchHistorySyncControlling
   MatchesTabView(..., historySyncController: historyStore)
   ```

2. **Add explicit sync trigger in `MatchesTabView.onAppear`**:
   ```swift
   .onAppear {
       guard isSignedIn else { return }
       if let syncController = historyStore as? MatchHistorySyncControlling {
           _ = syncController.requestManualSync()
       }
       refreshRecentAndPrompt()
       refreshSchedule()
   }
   ```

3. **Add loading state to `MatchHistoryView`**:
   ```swift
   @State private var isSyncing = false

   var body: some View {
       List {
           if isSyncing {
               HStack {
                   ProgressView()
                   Text("Syncing...")
               }
           }
           // ... existing content
       }
       .refreshable {
           await performSync()
       }
   }

   func performSync() async {
       guard let controller = historyStore as? MatchHistorySyncControlling else { return }
       isSyncing = true
       _ = controller.requestManualSync()
       try? await Task.sleep(nanoseconds: 500_000_000) // Wait for sync
       isSyncing = false
       resetAndLoadFirstPage()
   }
   ```

4. **Integrate with `SyncDiagnosticsCenter`** for error surfacing:
   ```swift
   // Listen to sync errors
   .onReceive(NotificationCenter.default.publisher(for: .syncNonrecoverableError)) { notification in
       if let error = notification.userInfo?["error"] as? String,
          let context = notification.userInfo?["context"] as? String,
          context.contains("match_history") {
           // Show user-friendly error message
           syncErrorMessage = "Failed to sync match history. Tap to retry."
       }
   }
   ```

5. **Verify notification posting** in repository:
   ```swift
   // In pullRemoteUpdates(), after context.save()
   if didChange {
       try store.context.save()
       NotificationCenter.default.post(name: .matchHistoryDidChange, object: nil)
       #if DEBUG
       log.debug("Match history sync complete: \(remoteBundles.count) bundles processed")
       #endif
   }
   ```

6. **Test with existing database match**:
   - Sign in as owner: `22fe9306-52cd-493f-830b-916a3c271371`
   - Navigate to Matches tab
   - Verify match `2f932df8-eda5-4b09-bf7c-e8cfecf8f7d0` appears in "Past" section
   - Pull-to-refresh should re-sync
   - Check logs for sync flow

#### Post-Implementation: Clean-up

1. **Remove temporary debug logging** from `SupabaseMatchHistoryRepository`
2. **Update documentation**:
   - Add sync trigger notes to `docs/plans/supabase/PLAN_Match_Ingest_Response_Decoding.md`
   - Document manual sync behavior
3. **Verify tests pass**: `xcodebuild test -scheme RefZoneiOS -destination 'platform=iOS Simulator,name=iPhone 15'`


---

### Phase 2: Implement Competitions Library (Priority: High) ✅ COMPLETED

**Problem**: No competition management infrastructure exists.

**Implementation Summary**:
- ✅ Created `Competition.swift` domain model
- ✅ Created `CompetitionRecord.swift` SwiftData model
- ✅ Created `CompetitionLibraryStoring` protocol
- ✅ Implemented `SwiftDataCompetitionLibraryStore` with full CRUD
- ✅ Implemented `InMemoryCompetitionLibraryStore` for testing
- ✅ Created `SupabaseCompetitionLibraryAPI` with fetch/sync/delete
- ✅ Created `SupabaseCompetitionSyncBacklogStore` for offline resilience
- ✅ Implemented `SupabaseCompetitionLibraryRepository` with queue-based sync
- ✅ Created `CompetitionsListView` with search and delete
- ✅ Created `CompetitionEditorView` with validation
- ✅ Integrated into `LibrarySettingsView`
- ✅ Added to SwiftData schema in `RefZoneiOSApp`
- ✅ Wired dependencies through app architecture

**Solution**: Build complete CRUD stack following existing team library patterns.

#### 2.1 Core Models

**New Files**:
- `RefZoneiOS/Core/Models/Competition.swift` - Domain model
- `RefZoneiOS/Core/Persistence/SwiftData/CompetitionRecord.swift` - SwiftData model

```swift
// Competition.swift (domain model)
struct Competition: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var level: String?
    var ownerId: String
    var createdAt: Date
    var updatedAt: Date
}

// CompetitionRecord.swift (SwiftData)
@Model
final class CompetitionRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var level: String?
    var ownerSupabaseId: String?
    var lastModifiedAt: Date
    var remoteUpdatedAt: Date?
    var needsRemoteSync: Bool

    // Relationships
    // Note: matches relationship exists in DB but may not need to be modeled client-side
}
```

#### 2.2 Persistence Layer

**New Files**:
- `RefZoneiOS/Core/Protocols/CompetitionLibraryStoring.swift` - Protocol
- `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataCompetitionLibraryStore.swift` - Store implementation
- `RefZoneiOS/Core/Persistence/InMemoryCompetitionLibraryStore.swift` - Test/preview store

**Protocol**:
```swift
protocol CompetitionLibraryStoring {
    func loadAll() throws -> [CompetitionRecord]
    func search(query: String) throws -> [CompetitionRecord]
    func create(name: String, level: String?) throws -> CompetitionRecord
    func update(_ competition: CompetitionRecord) throws
    func delete(_ competition: CompetitionRecord) throws
}
```

**Implementation**: Follow `SwiftDataTeamLibraryStore.swift` as reference template.

#### 2.3 Supabase Integration

**New Files**:
- `RefZoneiOS/Core/Platform/Supabase/SupabaseCompetitionLibraryAPI.swift` - HTTP client
- `RefZoneiOS/Core/Platform/Supabase/SupabaseCompetitionLibraryRepository.swift` - Sync coordinator
- `RefZoneiOS/Core/Platform/Supabase/SupabaseCompetitionSyncBacklogStore.swift` - Pending ops

**API Client**:
```swift
protocol SupabaseCompetitionLibraryServing {
    func fetchCompetitions(ownerId: UUID, updatedAfter: Date?) async throws -> [RemoteCompetition]
    func syncCompetition(_ request: CompetitionRequest) async throws -> SyncResult
    func deleteCompetition(competitionId: UUID) async throws
}
```

**Implementation**:
Use Supabase Postgrest queries via `SupabaseClient`:

```swift
// Fetch competitions
let rows: [CompetitionRowDTO] = try await supabaseClient.fetchRows(
    from: "competitions",
    select: "id, owner_id, name, level, created_at, updated_at",
    filters: [.equals("owner_id", value: ownerId.uuidString)],
    orderBy: "name",
    ascending: true,
    limit: 0,
    decoder: decoder
)

// Upsert competition
_ = try await supabaseClient
    .from("competitions")
    .upsert(competitionInput)
    .execute()

// Delete competition
_ = try await supabaseClient
    .from("competitions")
    .delete()
    .eq("id", value: competitionId.uuidString)
    .eq("owner_id", value: ownerId.uuidString) // Security: owner-scoped
    .execute()
```

**Database Queries** (for Supabase MCP validation):
```sql
-- Fetch competitions for owner
SELECT * FROM competitions WHERE owner_id = $1 ORDER BY name;

-- Insert competition
INSERT INTO competitions (id, owner_id, name, level, created_at, updated_at)
VALUES ($1, $2, $3, $4, NOW(), NOW());

-- Update competition
UPDATE competitions
SET name = $1, level = $2, updated_at = NOW()
WHERE id = $3 AND owner_id = $4;

-- Delete competition (owner-scoped for security)
DELETE FROM competitions WHERE id = $1 AND owner_id = $2;
```

**Repository**: Follow `SupabaseTeamLibraryRepository.swift` pattern:
- Wrap `SwiftDataCompetitionLibraryStore`
- Queue-based push/pull sync
- Handle auth state changes (sign-out wipes local cache)
- Post `NotificationCenter` updates
- Listen to `.syncStatusUpdate` for diagnostics

#### 2.4 UI Layer

**New Files**:
- `RefZoneiOS/Features/Library/Views/CompetitionsListView.swift` - List view
- `RefZoneiOS/Features/Library/Views/CompetitionEditorView.swift` - Create/edit form

**CompetitionsListView** (similar to `TeamsListView`):
- List with search bar
- Add button in toolbar
- Swipe-to-delete
- Navigation to editor sheet

**CompetitionEditorView**:
- Name field (required, max 100 chars)
- Level field (optional, max 50 chars)
- Save/Cancel buttons
- Form validation

**Modified Files**:
- `RefZoneiOS/Features/Settings/Views/LibrarySettingsView.swift` - Replace placeholder with navigation link


---

### Phase 3: Implement Venues Library (Priority: High) ✅ COMPLETED

**Problem**: No venue management infrastructure exists.

**Implementation Summary**:
- ✅ Created `Venue.swift` domain model
- ✅ Created `VenueRecord.swift` SwiftData model
- ✅ Created `VenueLibraryStoring` protocol
- ✅ Implemented `SwiftDataVenueLibraryStore` with full CRUD
- ✅ Implemented `InMemoryVenueLibraryStore` for testing
- ✅ Created `SupabaseVenueLibraryAPI` with fetch/sync/delete
- ✅ Created `SupabaseVenueSyncBacklogStore` for offline resilience
- ✅ Implemented `SupabaseVenueLibraryRepository` with queue-based sync
- ✅ Created `VenuesListView` with search and delete
- ✅ Created `VenueEditorView` with validation
- ✅ Integrated into `LibrarySettingsView`
- ✅ Added to SwiftData schema in `RefZoneiOSApp`
- ✅ Wired dependencies through app architecture

**Solution**: Build complete CRUD stack mirroring competitions implementation.

#### 3.1 Core Models

**New Files**:
- `RefZoneiOS/Core/Models/Venue.swift` - Domain model
- `RefZoneiOS/Core/Persistence/SwiftData/VenueRecord.swift` - SwiftData model

```swift
// Venue.swift
struct Venue: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var city: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var ownerId: String
    var createdAt: Date
    var updatedAt: Date
}

// VenueRecord.swift
@Model
final class VenueRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var city: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var ownerSupabaseId: String?
    var lastModifiedAt: Date
    var remoteUpdatedAt: Date?
    var needsRemoteSync: Bool
}
```

#### 3.2 Persistence Layer

**New Files**:
- `RefZoneiOS/Core/Protocols/VenueLibraryStoring.swift`
- `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataVenueLibraryStore.swift`
- `RefZoneiOS/Core/Persistence/InMemoryVenueLibraryStore.swift`

**Protocol**:
```swift
protocol VenueLibraryStoring {
    func loadAll() throws -> [VenueRecord]
    func search(query: String) throws -> [VenueRecord]
    func create(name: String, city: String?, country: String?) throws -> VenueRecord
    func update(_ venue: VenueRecord) throws
    func delete(_ venue: VenueRecord) throws
}
```

#### 3.3 Supabase Integration

**New Files**:
- `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueLibraryAPI.swift`
- `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueLibraryRepository.swift`
- `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueSyncBacklogStore.swift`

**Database Queries**:
- `SELECT * FROM venues WHERE owner_id = $1 ORDER BY name`
- `INSERT INTO venues (id, owner_id, name, city, country, latitude, longitude) VALUES (...)`
- `UPDATE venues SET name = $1, city = $2, country = $3, updated_at = NOW() WHERE id = $4`
- `DELETE FROM venues WHERE id = $1 AND owner_id = $2`

#### 3.4 UI Layer

**New Files**:
- `RefZoneiOS/Features/Library/Views/VenuesListView.swift`
- `RefZoneiOS/Features/Library/Views/VenueEditorView.swift`

**VenueEditorView** fields:
- Name (required)
- City (optional)
- Country (optional)
- Coordinates (optional, future: map picker)

**Modified Files**:
- `RefZoneiOS/Features/Settings/Views/LibrarySettingsView.swift` - Replace placeholder


---

### Phase 4: Integrate Team Selection in Match Setup (Priority: High) ✅ Completed 2025-10-01

**Problem**: `MatchSetupView` uses text fields instead of team picker.

**Solution**: Add team selection UI with fallback to manual entry, and extend domain models to support team/competition/venue IDs.

#### 4.1 Domain Model Extensions (Prerequisites)

**Extend `Match` (RefWatchCore)**:

The `Match` model needs optional foreign key fields for library entities. These must default to `nil` to maintain watchOS compatibility.

```swift
// In RefWatchCore/Sources/RefWatchCore/Models/Match.swift
struct Match {
    // Existing fields...

    // Optional team references (watchOS-compatible defaults)
    var homeTeamId: UUID? = nil
    var awayTeamId: UUID? = nil
    var competitionId: UUID? = nil
    var competitionName: String? = nil
    var venueId: UUID? = nil
    var venueName: String? = nil
}
```

**Extend `CompletedMatch`**:

To maintain backward compatibility with existing persisted matches:

```swift
// Bump schema version
static let schemaVersion = 2 // Increment from current version

// Update decoder to handle legacy payloads
init(from decoder: Decoder) throws {
    // ... existing decoding

    // New optional fields with fallback
    self.homeTeamId = try? container.decodeIfPresent(UUID.self, forKey: .homeTeamId)
    self.awayTeamId = try? container.decodeIfPresent(UUID.self, forKey: .awayTeamId)
    self.competitionId = try? container.decodeIfPresent(UUID.self, forKey: .competitionId)
    self.competitionName = try? container.decodeIfPresent(String.self, forKey: .competitionName)
    self.venueId = try? container.decodeIfPresent(UUID.self, forKey: .venueId)
    self.venueName = try? container.decodeIfPresent(String.self, forKey: .venueName)
}
```

**Extend `CompletedMatchRecord` (SwiftData)**:

Add indexed columns for foreign keys and name caching:

```swift
@Model
final class CompletedMatchRecord {
    // Existing fields...

    // Add indexed columns for foreign keys (for future query optimization)
    var homeTeamId: UUID?
    var awayTeamId: UUID?
    var competitionId: UUID?
    var venueId: UUID?

    // Name caching for offline display (avoid JOIN queries)
    var competitionName: String?
    var venueName: String?
}
```

**Update `SwiftDataMatchHistoryStore` save path**:

```swift
func save(_ match: CompletedMatch) throws {
    // ... existing save logic

    // Persist new fields
    existing.homeTeamId = snapshot.match.homeTeamId
    existing.awayTeamId = snapshot.match.awayTeamId
    existing.competitionId = snapshot.match.competitionId
    existing.competitionName = snapshot.match.competitionName
    existing.venueId = snapshot.match.venueId
    existing.venueName = snapshot.match.venueName
}
```

**Update `SupabaseMatchHistoryRepository.makeMatchBundleRequest()`**:

The repository already has these fields in the payload structure. Ensure they're populated from the `Match` model:

```swift
let matchPayload = SupabaseMatchIngestService.MatchBundleRequest.MatchPayload(
    // ... existing fields
    homeTeamId: match.homeTeamId,  // Now populated instead of nil
    homeTeamName: match.homeTeam,
    awayTeamId: match.awayTeamId,  // Now populated instead of nil
    awayTeamName: match.awayTeam,
    competitionId: match.competitionId,
    competitionName: match.competitionName,
    venueId: match.venueId,
    venueName: match.venueName,
    // ... remaining fields
)
```

#### 4.2 UI Implementation

**Modified Files**:
- `RefZoneiOS/Features/Match/MatchSetup/MatchSetupView.swift`

**New UI Components**:
1. **Team Picker Buttons**:
   - Replace `TextField` with button showing selected team or "Select Team"
   - Button opens sheet with team list
   - Show selected team name after selection

2. **Team Selection Sheet**:
   - Searchable list of teams from `teamStore`
   - "Use Custom Name" button to fallback to text entry
   - Recently used teams at top (optional enhancement)

3. **Implementation**:
```swift
@State private var selectedHomeTeam: TeamRecord?
@State private var selectedAwayTeam: TeamRecord?
@State private var showingHomeTeamPicker = false
@State private var showingAwayTeamPicker = false
@State private var useCustomHomeTeam = false
@State private var useCustomAwayTeam = false

// In form:
Section("Teams") {
    if useCustomHomeTeam {
        TextField("Home Team", text: $homeTeam)
        Button("Select from Library") {
            useCustomHomeTeam = false
            showingHomeTeamPicker = true
        }
    } else {
        Button {
            showingHomeTeamPicker = true
        } label: {
            HStack {
                Text("Home Team")
                Spacer()
                Text(selectedHomeTeam?.name ?? "Select...")
                    .foregroundStyle(selectedHomeTeam == nil ? .secondary : .primary)
            }
        }
        Button("Use Custom Name") { useCustomHomeTeam = true }
    }
    // Similar for away team
}
```

**Team Picker Sheet** (new component):
```swift
struct TeamPickerSheet: View {
    let teamStore: TeamLibraryStoring
    let onSelect: (TeamRecord) -> Void
    @State private var teams: [TeamRecord] = []
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List(filteredTeams) { team in
                Button {
                    onSelect(team)
                } label: {
                    VStack(alignment: .leading) {
                        Text(team.name).font(.headline)
                        if let division = team.division {
                            Text(division).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Team")
        }
        .onAppear { loadTeams() }
    }
}
```

**Integration with Database**:
- When team selected, populate `Match.homeTeamId` and `Match.awayTeamId`
- Edge function `matches-ingest` already accepts these fields in the payload
- Repository `makeMatchBundleRequest()` will now forward IDs to Supabase
- Database will link matches to teams via foreign keys

**Testing**:
1. **Unit tests**: Extend `MatchSetupViewTests` to verify team ID population
2. **Repository tests**: Assert `makeMatchBundleRequest()` includes team IDs when present
3. **End-to-end**: Start match with library team → verify `matches.home_team_id` in database:
   ```sql
   SELECT
       m.id,
       m.home_team_name,
       m.home_team_id,
       t.name as linked_team_name
   FROM matches m
   LEFT JOIN teams t ON m.home_team_id = t.id
   WHERE m.id = 'newly-created-match-id';
   ```


---

### Phase 5: Connect Competitions & Venues to Match Setup (Priority: Medium)

**Enhancement**: Allow selecting competition and venue when creating match.

**Modified Files**:
- `RefZoneiOS/Features/Match/MatchSetup/MatchSetupView.swift`

**Implementation**:
1. Add optional competition picker (similar to team picker)
2. Add optional venue picker
3. Pass IDs to `Match` model (may need to extend model)
4. Update `SupabaseMatchHistoryRepository.makeMatchBundleRequest()` to include IDs

**Note**: Requires Phase 2 & 3 completion.


---

## Testing Strategy

### Unit Tests

**Match History** (`RefZoneiOSTests/`):
- `SupabaseMatchHistoryRepositoryTests` - Verify pull triggers local save
- Test notification posting after remote sync
- Test manual sync via `requestManualSync()` triggers pull

**Competitions**:
- `SwiftDataCompetitionLibraryStoreTests.swift` - CRUD operations
- `SupabaseCompetitionLibraryRepositoryTests.swift` - Sync behavior with mocked Supabase client
- `SupabaseCompetitionLibraryAPITests.swift` - HTTP request/response mocking

**Venues**:
- `SwiftDataVenueLibraryStoreTests.swift` - CRUD operations
- `SupabaseVenueLibraryRepositoryTests.swift` - Sync behavior with mocked Supabase client
- `SupabaseVenueLibraryAPITests.swift` - HTTP request/response mocking

**Domain Model Compatibility**:
- Test `CompletedMatch` decoding with legacy payloads (no team/competition/venue IDs)
- Test `CompletedMatch` decoding with new payloads (includes IDs)
- Verify schema version migration doesn't break existing SwiftData records

### Snapshot/UI Tests

**Match History** (`RefZoneiOSUITests/`):
- Snapshot test: History view with 0, 1, 5, 50+ matches
- Snapshot test: History view during sync (loading state)
- UI test: Pull-to-refresh triggers sync and displays new match
- UI test: Sync error message appears when pull fails

**Team Selection**:
- Snapshot test: Team picker with empty state, 1 team, 10+ teams
- Snapshot test: Match setup with selected teams vs manual entry
- UI test: Select team → verify name appears in setup form → start match

**Competitions & Venues**:
- Snapshot test: List views with empty state and populated state
- Snapshot test: Editor forms with validation errors
- UI test: Create → Edit → Delete flow for both entities

### Integration Tests

1. **End-to-End Match History**:
   - Sign in → complete match on watch → verify appears in iOS history
   - Manual sync button triggers pull from database

2. **Competition Sync**:
   - Create competition → verify in database
   - Create on another device → verify appears via pull sync

3. **Venue Sync**:
   - Same as competitions

4. **Match Setup with Library**:
   - Select team from library → start match → verify team_id in database
   - Select competition → verify competition_id in match record

### Database Verification (via Supabase MCP)

After implementing each feature, validate database state using the Supabase MCP tool:

**Competition Sync Validation**:
```sql
-- Verify competitions created by user
SELECT id, name, level, owner_id, created_at, updated_at
FROM competitions
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY created_at DESC;

-- Check for orphaned competitions (invalid owner_id)
SELECT COUNT(*) FROM competitions WHERE owner_id NOT IN (SELECT id FROM users);
```

**Venue Sync Validation**:
```sql
-- Verify venues created by user
SELECT id, name, city, country, owner_id, created_at, updated_at
FROM venues
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY created_at DESC;

-- Check venues with coordinates
SELECT name, city, latitude, longitude FROM venues WHERE latitude IS NOT NULL;
```

**Match Foreign Key Validation**:
```sql
-- Verify match has proper team/competition/venue links
SELECT
    m.id,
    m.started_at,
    m.home_team_name,
    m.home_team_id,
    ht.name as home_team_linked_name,
    m.away_team_name,
    m.away_team_id,
    at.name as away_team_linked_name,
    m.competition_id,
    c.name as competition_linked_name,
    m.venue_id,
    v.name as venue_linked_name
FROM matches m
LEFT JOIN teams ht ON m.home_team_id = ht.id
LEFT JOIN teams at ON m.away_team_id = at.id
LEFT JOIN competitions c ON m.competition_id = c.id
LEFT JOIN venues v ON m.venue_id = v.id
WHERE m.owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY m.started_at DESC
LIMIT 10;

-- Check for referential integrity issues
SELECT
    m.id,
    m.home_team_name,
    m.home_team_id,
    CASE WHEN m.home_team_id IS NOT NULL AND ht.id IS NULL THEN 'BROKEN' ELSE 'OK' END as home_link
FROM matches m
LEFT JOIN teams ht ON m.home_team_id = ht.id
WHERE m.home_team_id IS NOT NULL AND ht.id IS NULL;
```

**Sync State Verification**:
```sql
-- Check updated_at timestamps for sync cursor validation
SELECT
    'competitions' as table_name,
    COUNT(*) as total_rows,
    MAX(updated_at) as latest_update
FROM competitions
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
UNION ALL
SELECT
    'venues' as table_name,
    COUNT(*) as total_rows,
    MAX(updated_at) as latest_update
FROM venues
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
UNION ALL
SELECT
    'teams' as table_name,
    COUNT(*) as total_rows,
    MAX(updated_at) as latest_update
FROM teams
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371';
```

---

## Migration & Data Considerations

### ModelContainer Updates

**File**: `RefZoneiOS/Core/Persistence/SwiftData/ModelContainerFactory.swift`

Add to schema registration:
```swift
schema: Schema([
    // Existing...
    TeamRecord.self,
    PlayerRecord.self,
    // Add:
    CompetitionRecord.self,
    VenueRecord.self
])
```

### App Dependency Injection

**File**: `RefZoneiOS/App/RefZoneiOSApp.swift`

Initialize new repositories:
```swift
let competitionStore = SwiftDataCompetitionLibraryStore(container: container, auth: authController)
let competitionRepository = SupabaseCompetitionLibraryRepository(
    store: competitionStore,
    authStateProvider: authController
)

let venueStore = SwiftDataVenueLibraryStore(container: container, auth: authController)
let venueRepository = SupabaseVenueLibraryRepository(
    store: venueStore,
    authStateProvider: authController
)
```

Pass to views via Environment or direct injection.

---

## Rollout Plan

### Phase 1 (Day 1): Match History Fix
- Critical bug fix
- No database changes needed
- Low risk, high impact
- Can deploy independently

### Phase 2-3 (Days 2-3): Competitions & Venues
- Run in parallel (similar implementations)
- Minimal risk (new features, no data migration)
- Database already has tables
- Can deploy together

### Phase 4 (Day 3-4): Team Selection ✅ Completed 2025-10-01
- Depends on Phase 1 completion
- Enhances existing match setup
- Backward compatible (can still use text entry)

### Phase 5 (Day 4): Competition/Venue Integration
- Depends on Phases 2-3
- Optional enhancement
- Can defer if timeline is tight

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| SwiftData migration issues | High | Test schema changes thoroughly; maintain backward compatibility |
| Match history sync performance with large datasets | Medium | Repository already uses cursor-based pagination; verify with >100 matches |
| Team picker UX on small screens | Low | Use sheet presentation; maintain text entry fallback |
| Competitions/Venues empty database | Low | Add onboarding prompt or "Create first..." placeholder |

---

## Success Criteria

### Feature 1: Match History Display
- [ ] Completed matches from database appear in History tab
- [ ] Pull-to-refresh triggers remote sync
- [ ] New matches appear within 30 seconds of completion
- [ ] No duplicate entries in list

### Feature 2: Competitions Library
- [ ] Users can create, edit, delete competitions
- [ ] Changes sync to database
- [ ] Competitions from other devices appear via pull sync
- [ ] Search functionality works

### Feature 3: Venues Library
- [ ] Users can create, edit, delete venues
- [ ] Changes sync to database
- [ ] Venues from other devices appear via pull sync
- [ ] Search functionality works

### Feature 4: Team Selection
- [ ] Team picker shows all saved teams
- [ ] Selected team name appears in match setup
- [ ] Match record includes team_id in database
- [ ] Text entry fallback still works

---

## Open Questions for Team Lead

1. **Match History Priority**: Should we add a manual "Sync Now" button or rely on automatic sync?

2. **Empty State UX**: For competitions/venues, do you want:
   - Immediate redirect to create form?
   - Explanatory placeholder with CTA button?
   - Pre-populated sample data?

3. **Team Selection UX**: Should the picker:
   - Remember recently used teams?
   - Show team colors/logos (if added later)?
   - Support multi-select for bulk operations?

4. **Competition/Venue Fields**: Are the minimal fields sufficient or should we add:
   - Competition: season, start/end dates, organizer
   - Venue: capacity, surface type, timezone

5. **Testing Scope**: Should we add UI tests for these flows or rely on unit + integration tests?

---

## Appendix: File Structure

```
RefZoneiOS/
├── Core/
│   ├── Models/
│   │   ├── Competition.swift [NEW]
│   │   └── Venue.swift [NEW]
│   ├── Persistence/
│   │   ├── SwiftData/
│   │   │   ├── CompetitionRecord.swift [NEW]
│   │   │   ├── VenueRecord.swift [NEW]
│   │   │   ├── SwiftDataCompetitionLibraryStore.swift [NEW]
│   │   │   ├── SwiftDataVenueLibraryStore.swift [NEW]
│   │   │   └── ModelContainerFactory.swift [MODIFIED]
│   │   ├── InMemoryCompetitionLibraryStore.swift [NEW]
│   │   └── InMemoryVenueLibraryStore.swift [NEW]
│   ├── Platform/
│   │   └── Supabase/
│   │       ├── SupabaseCompetitionLibraryAPI.swift [NEW]
│   │       ├── SupabaseCompetitionLibraryRepository.swift [NEW]
│   │       ├── SupabaseCompetitionSyncBacklogStore.swift [NEW]
│   │       ├── SupabaseVenueLibraryAPI.swift [NEW]
│   │       ├── SupabaseVenueLibraryRepository.swift [NEW]
│   │       ├── SupabaseVenueSyncBacklogStore.swift [NEW]
│   │       └── SupabaseMatchHistoryRepository.swift [MODIFIED]
│   └── Protocols/
│       ├── CompetitionLibraryStoring.swift [NEW]
│       └── VenueLibraryStoring.swift [NEW]
├── Features/
│   ├── Library/
│   │   └── Views/
│   │       ├── CompetitionsListView.swift [NEW]
│   │       ├── CompetitionEditorView.swift [NEW]
│   │       ├── VenuesListView.swift [NEW]
│   │       └── VenueEditorView.swift [NEW]
│   ├── Match/
│   │   └── MatchSetup/
│   │       └── MatchSetupView.swift [MODIFIED]
│   ├── Matches/
│   │   └── Views/
│   │       └── MatchesTabView.swift [MODIFIED]
│   └── Settings/
│       └── Views/
│           └── LibrarySettingsView.swift [MODIFIED]
└── App/
    └── RefZoneiOSApp.swift [MODIFIED]
```

---

## Timeline Summary

| Phase | Estimated Effort | Dependencies |
|-------|------------------|--------------|
| 1: Match History Fix | 4-6 hours | None |
| 2: Competitions Library | 12-16 hours | None |
| 3: Venues Library | 12-16 hours | None |
| 4: Team Selection Integration | 8-10 hours | None (domain models prerequisite) |
| 5: Competition/Venue in Match Setup | 4-6 hours | Phases 2, 3, 4 |
| **Total** | **40-54 hours** | **~3-5 days** |

**Note**: Phase 4 includes domain model extensions that are prerequisites for Phase 5.

---

**Next Steps**: Please review and approve this plan. Once approved, I will begin implementation starting with Phase 1 (critical match history fix).
