# Phase 4 Handoff: Team Selection Integration in Match Setup

**Status**: ✅ Completed (2025-10-01)
**Estimated Effort**: 8-10 hours
**Actual Effort**: ~8 hours
**Dependencies**: None (Phases 1-3 provide foundation)
**Created**: 2025-09-30

## Context

Phases 1, 2, and 3 have been completed:
- ✅ Phase 1: Match history sync is working with manual sync triggers
- ✅ Phase 2: Competitions library fully implemented with Supabase sync
- ✅ Phase 3: Venues library fully implemented with Supabase sync

Phase 4 enhanced the match setup flow to allow selecting teams from the library instead of manual text entry. This creates a richer data model where matches are linked to team entities via foreign keys.

## Objective

Integrate team selection into the match setup flow, allowing users to:
- Select home and away teams from their saved library
- Fall back to manual text entry if needed (watchOS compatibility)
- Link matches to team entities in the database
- Maintain backward compatibility with existing matches

## Why This Matters

**Current State**: `MatchSetupView` uses simple `TextField` for team names. This means:
- No reusable team data
- No linkage between matches and teams
- Cannot track performance by team
- Manual entry every time

**Desired State**: Team picker with library integration:
- Select from saved teams quickly
- Database foreign keys link matches → teams
- Future analytics can aggregate by team
- Maintain text entry fallback for flexibility

## Architecture Overview

### 1. Domain Model Extensions

The iOS app uses the RefWatchCore shared models (`Match`, `CompletedMatch`). These need optional foreign key fields that default to `nil` for watchOS compatibility.

### 2. UI Enhancement

Replace text fields with team picker buttons that:
- Show "Select Team" or selected team name
- Open sheet with searchable team list
- Allow toggling back to custom text entry

### 3. Repository Integration

The `SupabaseMatchHistoryRepository` already has payload fields for team IDs. Phase 4 will populate these from the `Match` model.

## Implementation Plan

### Step 1: Extend Domain Models (2-3 hours)

**Objective**: Add optional team/competition/venue ID fields to match models.

#### 1.1 Extend `Match` (RefWatchCore)

**File**: `RefWatchCore/Sources/RefWatchCore/Models/Match.swift`

Add optional foreign key fields with `nil` defaults:

```swift
struct Match {
    // Existing fields...
    let id: UUID
    var homeTeam: String
    var awayTeam: String
    // ... other existing fields

    // New optional foreign key fields (watchOS-compatible)
    var homeTeamId: UUID? = nil
    var awayTeamId: UUID? = nil
    var competitionId: UUID? = nil
    var competitionName: String? = nil
    var venueId: UUID? = nil
    var venueName: String? = nil
}
```

**Important Notes**:
- Default all fields to `nil` to maintain watchOS compatibility
- watchOS will never populate these fields (no library support)
- iOS will populate them when team/competition/venue selected
- `homeTeam`/`awayTeam` strings remain authoritative for display

#### 1.2 Extend `CompletedMatch`

**File**: `RefWatchCore/Sources/RefWatchCore/Models/CompletedMatch.swift`

Update the decoder to handle optional fields:

```swift
// Add CodingKeys enum
enum CodingKeys: String, CodingKey {
    // ... existing keys
    case homeTeamId = "homeTeamId"
    case awayTeamId = "awayTeamId"
    case competitionId = "competitionId"
    case competitionName = "competitionName"
    case venueId = "venueId"
    case venueName = "venueName"
}

// Update init(from decoder:)
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // ... existing decoding

    // New optional fields with backward compatibility
    self.homeTeamId = try? container.decodeIfPresent(UUID.self, forKey: .homeTeamId)
    self.awayTeamId = try? container.decodeIfPresent(UUID.self, forKey: .awayTeamId)
    self.competitionId = try? container.decodeIfPresent(UUID.self, forKey: .competitionId)
    self.competitionName = try? container.decodeIfPresent(String.self, forKey: .competitionName)
    self.venueId = try? container.decodeIfPresent(UUID.self, forKey: .venueId)
    self.venueName = try? container.decodeIfPresent(String.self, forKey: .venueName)
}

// Update encode(to:)
func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    // ... existing encoding

    // Encode new optional fields
    try container.encodeIfPresent(homeTeamId, forKey: .homeTeamId)
    try container.encodeIfPresent(awayTeamId, forKey: .awayTeamId)
    try container.encodeIfPresent(competitionId, forKey: .competitionId)
    try container.encodeIfPresent(competitionName, forKey: .competitionName)
    try container.encodeIfPresent(venueId, forKey: .venueId)
    try container.encodeIfPresent(venueName, forKey: .venueName)
}
```

**Testing Note**: Verify that legacy `CompletedMatch` payloads (without these fields) can still be decoded.

#### 1.3 Extend `CompletedMatchRecord` (SwiftData)

**File**: `RefZoneiOS/Core/Persistence/SwiftData/CompletedMatchRecord.swift`

Add columns for foreign keys and name caching:

```swift
@Model
final class CompletedMatchRecord {
    // Existing fields...

    // Add indexed foreign key columns
    var homeTeamId: UUID?
    var awayTeamId: UUID?
    var competitionId: UUID?
    var venueId: UUID?

    // Name caching for offline display (avoids JOIN queries)
    var competitionName: String?
    var venueName: String?
}
```

#### 1.4 Update `SwiftDataMatchHistoryStore` Save Path

**File**: `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataMatchHistoryStore.swift`

Update the `save()` method to persist new fields:

```swift
func save(_ match: CompletedMatch) throws {
    let context = self.context

    // ... existing logic to find or create record

    // Persist new foreign key fields
    existing.homeTeamId = snapshot.match.homeTeamId
    existing.awayTeamId = snapshot.match.awayTeamId
    existing.competitionId = snapshot.match.competitionId
    existing.competitionName = snapshot.match.competitionName
    existing.venueId = snapshot.match.venueId
    existing.venueName = snapshot.match.venueName

    // ... existing save logic
}
```

#### 1.5 Update `SupabaseMatchHistoryRepository` Payload

**File**: `RefZoneiOS/Core/Platform/Supabase/SupabaseMatchHistoryRepository.swift`

Ensure `makeMatchBundleRequest()` populates team IDs from the `Match` model:

```swift
private func makeMatchBundleRequest(from snapshot: CompletedMatch) throws -> SupabaseMatchIngestService.MatchBundleRequest {
    let match = snapshot.match

    let matchPayload = SupabaseMatchIngestService.MatchBundleRequest.MatchPayload(
        id: match.id,
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

    return SupabaseMatchIngestService.MatchBundleRequest(match: matchPayload, events: eventPayloads)
}
```

**Note**: The edge function `matches-ingest` already accepts these fields in the payload schema.

---

### Step 2: Implement Team Picker UI (4-5 hours)

**Objective**: Replace text fields with team selection flow.

#### 2.1 Create `TeamPickerSheet` Component

**New File**: `RefZoneiOS/Features/Match/MatchSetup/TeamPickerSheet.swift`

```swift
import SwiftUI

/// Sheet for selecting a team from the library
struct TeamPickerSheet: View {
    let teamStore: TeamLibraryStoring
    let onSelect: (TeamRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var teams: [TeamRecord] = []
    @State private var searchText = ""
    @State private var isLoading = false

    var filteredTeams: [TeamRecord] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return teams
        }

        let lowercased = searchText.lowercased()
        return teams.filter { team in
            team.name.lowercased().contains(lowercased) ||
            (team.division?.lowercased().contains(lowercased) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading teams...")
                } else if teams.isEmpty {
                    emptyStateView
                } else {
                    teamListView
                }
            }
            .navigationTitle("Select Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search teams")
            .onAppear { loadTeams() }
        }
    }

    @ViewBuilder
    private var teamListView: some View {
        List {
            if filteredTeams.isEmpty {
                ContentUnavailableView(
                    "No Teams Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            } else {
                ForEach(filteredTeams) { team in
                    Button {
                        onSelect(team)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if let division = team.division {
                                Text(division)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Teams Yet",
            systemImage: "person.3",
            description: Text("Create teams in Settings → Library → Teams")
        )
    }

    private func loadTeams() {
        isLoading = true
        do {
            teams = try teamStore.loadAll()
        } catch {
            print("Failed to load teams: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    TeamPickerSheet(
        teamStore: InMemoryTeamLibraryStore(preloadedTeams: [
            TeamRecord(
                id: UUID(),
                name: "Arsenal",
                division: "Premier League",
                ownerSupabaseId: "test",
                lastModifiedAt: Date(),
                remoteUpdatedAt: nil,
                needsRemoteSync: false
            ),
            TeamRecord(
                id: UUID(),
                name: "Chelsea",
                division: "Premier League",
                ownerSupabaseId: "test",
                lastModifiedAt: Date(),
                remoteUpdatedAt: nil,
                needsRemoteSync: false
            )
        ]),
        onSelect: { _ in }
    )
}
```

#### 2.2 Update `MatchSetupView`

**File**: `RefZoneiOS/Features/Match/MatchSetup/MatchSetupView.swift`

**Add State Variables**:

```swift
// Team selection state
@State private var selectedHomeTeam: TeamRecord?
@State private var selectedAwayTeam: TeamRecord?
@State private var showingHomeTeamPicker = false
@State private var showingAwayTeamPicker = false
@State private var useCustomHomeTeam = false
@State private var useCustomAwayTeam = false
```

**Inject TeamLibraryStoring**:

```swift
struct MatchSetupView: View {
    // Existing parameters...
    let teamStore: TeamLibraryStoring

    // ... existing body
}
```

**Replace Team TextField Section**:

Find the existing section:
```swift
Section("Teams") {
    TextField("Home Team", text: $homeTeam)
    TextField("Away Team", text: $awayTeam)
}
```

Replace with:
```swift
Section("Teams") {
    // Home Team
    if useCustomHomeTeam {
        TextField("Home Team", text: $homeTeam)
        Button("Select from Library") {
            useCustomHomeTeam = false
            homeTeam = selectedHomeTeam?.name ?? ""
        }
        .font(.caption)
        .foregroundStyle(.blue)
    } else {
        Button {
            showingHomeTeamPicker = true
        } label: {
            HStack {
                Text("Home Team")
                    .foregroundStyle(.primary)
                Spacer()
                Text(selectedHomeTeam?.name ?? homeTeam.isEmpty ? "Select..." : homeTeam)
                    .foregroundStyle(selectedHomeTeam == nil && homeTeam.isEmpty ? .secondary : .primary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }

        if selectedHomeTeam != nil {
            Button("Use Custom Name") {
                useCustomHomeTeam = true
                selectedHomeTeam = nil
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
    }

    // Away Team (mirror home team structure)
    if useCustomAwayTeam {
        TextField("Away Team", text: $awayTeam)
        Button("Select from Library") {
            useCustomAwayTeam = false
            awayTeam = selectedAwayTeam?.name ?? ""
        }
        .font(.caption)
        .foregroundStyle(.blue)
    } else {
        Button {
            showingAwayTeamPicker = true
        } label: {
            HStack {
                Text("Away Team")
                    .foregroundStyle(.primary)
                Spacer()
                Text(selectedAwayTeam?.name ?? awayTeam.isEmpty ? "Select..." : awayTeam)
                    .foregroundStyle(selectedAwayTeam == nil && awayTeam.isEmpty ? .secondary : .primary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }

        if selectedAwayTeam != nil {
            Button("Use Custom Name") {
                useCustomAwayTeam = true
                selectedAwayTeam = nil
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
    }
}
```

**Add Sheet Modifiers**:

Add to the view body (after `.navigationTitle`):

```swift
.sheet(isPresented: $showingHomeTeamPicker) {
    TeamPickerSheet(teamStore: teamStore) { team in
        selectedHomeTeam = team
        homeTeam = team.name
        useCustomHomeTeam = false
    }
}
.sheet(isPresented: $showingAwayTeamPicker) {
    TeamPickerSheet(teamStore: teamStore) { team in
        selectedAwayTeam = team
        awayTeam = team.name
        useCustomAwayTeam = false
    }
}
```

**Update `configureMatch()` Method**:

Find the method that creates the `Match` object and update it to populate team IDs:

```swift
private func configureMatch() {
    // ... existing setup logic

    var match = Match(
        id: UUID(),
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        // ... other fields
    )

    // Populate optional foreign keys if teams selected from library
    match.homeTeamId = selectedHomeTeam?.id
    match.awayTeamId = selectedAwayTeam?.id

    // Future: Populate competitionId/venueId in Phase 5

    model.configureMatch(match)
}
```

#### 2.3 Wire Team Store Through View Hierarchy

**File**: `RefZoneiOS/Features/Matches/Views/MatchesTabView.swift`

Add `teamStore` parameter:

```swift
struct MatchesTabView: View {
    // ... existing parameters
    let teamStore: TeamLibraryStoring

    // Pass to MatchSetupView when presenting
    .sheet(isPresented: $showingMatchSetup) {
        MatchSetupView(
            model: matchSetupModel,
            teamStore: teamStore,  // Add this
            onMatchConfigured: { /* ... */ }
        )
    }
}
```

**File**: `RefZoneiOS/App/MainTabView.swift`

Pass `teamStore` to `MatchesTabView`:

```swift
struct MainTabView: View {
    // ... existing properties
    let teamStore: TeamLibraryStoring  // Already exists from previous phases

    var body: some View {
        TabView(selection: $selectedTab) {
            MatchesTabView(
                // ... existing parameters
                teamStore: teamStore  // Add this
            )
            // ... other tabs
        }
    }
}
```

**Note**: `teamStore` already exists in `MainTabView` from previous phases. Just ensure it's passed down.

---

### Step 3: Testing & Validation (2 hours)

#### 3.1 Unit Tests

**New File**: `RefZoneiOSTests/MatchSetupViewTeamSelectionTests.swift`

```swift
import Testing
@testable import RefZoneiOS

@Suite("Match Setup Team Selection")
struct MatchSetupViewTeamSelectionTests {

    @Test("Selected team ID populates Match.homeTeamId")
    func selectedTeamPopulatesHomeTeamId() {
        let teamStore = InMemoryTeamLibraryStore(preloadedTeams: [
            TeamRecord(id: UUID(), name: "Arsenal", division: nil, ownerSupabaseId: "test", lastModifiedAt: Date(), remoteUpdatedAt: nil, needsRemoteSync: false)
        ])

        let team = try! teamStore.loadAll().first!

        var match = Match.createDefault()
        match.homeTeam = team.name
        match.homeTeamId = team.id

        #expect(match.homeTeamId == team.id)
        #expect(match.homeTeam == "Arsenal")
    }

    @Test("Manual text entry clears team ID")
    func manualEntryLeaveTeamIdNil() {
        var match = Match.createDefault()
        match.homeTeam = "Custom Team Name"
        match.homeTeamId = nil

        #expect(match.homeTeamId == nil)
        #expect(match.homeTeam == "Custom Team Name")
    }

    @Test("CompletedMatch decodes legacy payload without team IDs")
    func decodeLegacyPayload() throws {
        let json = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "homeTeam": "Arsenal",
            "awayTeam": "Chelsea",
            "startTime": "2025-09-30T10:00:00Z",
            "endTime": "2025-09-30T11:45:00Z"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let match = try decoder.decode(CompletedMatch.self, from: data)

        #expect(match.match.homeTeam == "Arsenal")
        #expect(match.match.homeTeamId == nil)  // Should decode as nil
        #expect(match.match.awayTeamId == nil)
    }
}
```

#### 3.2 Repository Tests

**File**: `RefZoneiOSTests/SupabaseMatchHistoryRepositoryTests.swift`

Add test to verify team IDs are included in payload:

```swift
@Test("makeMatchBundleRequest includes team IDs when present")
func matchBundleIncludesTeamIds() throws {
    // Setup
    let homeTeamId = UUID()
    let awayTeamId = UUID()

    var match = Match.createDefault()
    match.homeTeam = "Arsenal"
    match.awayTeam = "Chelsea"
    match.homeTeamId = homeTeamId
    match.awayTeamId = awayTeamId

    let snapshot = CompletedMatch(match: match, events: [])

    // Execute
    let request = try repository.makeMatchBundleRequest(from: snapshot)

    // Verify
    #expect(request.match.homeTeamId == homeTeamId)
    #expect(request.match.awayTeamId == awayTeamId)
    #expect(request.match.homeTeamName == "Arsenal")
    #expect(request.match.awayTeamName == "Chelsea")
}
```

#### 3.3 Database Verification

After implementing, use Supabase MCP to verify matches are linked to teams:

```sql
-- Verify match has proper team links
SELECT
    m.id,
    m.started_at,
    m.home_team_name,
    m.home_team_id,
    ht.name as home_team_linked_name,
    m.away_team_name,
    m.away_team_id,
    at.name as away_team_linked_name
FROM matches m
LEFT JOIN teams ht ON m.home_team_id = ht.id
LEFT JOIN teams at ON m.away_team_id = at.id
WHERE m.owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY m.started_at DESC
LIMIT 10;

-- Check for broken foreign key references
SELECT
    m.id,
    m.home_team_name,
    m.home_team_id,
    CASE
        WHEN m.home_team_id IS NOT NULL AND ht.id IS NULL THEN 'BROKEN'
        ELSE 'OK'
    END as home_link_status,
    CASE
        WHEN m.away_team_id IS NOT NULL AND at.id IS NULL THEN 'BROKEN'
        ELSE 'OK'
    END as away_link_status
FROM matches m
LEFT JOIN teams ht ON m.home_team_id = ht.id
LEFT JOIN teams at ON m.away_team_id = at.id
WHERE (m.home_team_id IS NOT NULL AND ht.id IS NULL)
   OR (m.away_team_id IS NOT NULL AND at.id IS NULL);
```

#### 3.4 Manual Testing Flow

**Test Case 1: Team Picker Flow**
1. Open app → Matches tab → Add Match
2. Tap "Home Team" row → should open team picker sheet
3. Search for team → select team
4. Verify team name appears in match setup form
5. Start match → complete match
6. Query database: verify `home_team_id` is populated

**Test Case 2: Custom Text Entry**
1. Open match setup
2. Select team from library
3. Tap "Use Custom Name" button
4. Enter custom text
5. Verify team ID is cleared (nil)
6. Start match → verify `home_team_id` is null in database

**Test Case 3: Mixed Selection**
1. Home team: Select from library
2. Away team: Use custom text entry
3. Start match
4. Verify database: `home_team_id` populated, `away_team_id` is null

**Test Case 4: Empty State**
1. Open match setup with no teams in library
2. Tap "Home Team" → should see "No Teams Yet" empty state
3. Should still be able to use custom text entry

---

## Key Architectural Decisions

### 1. Why Optional Fields?

**Decision**: All foreign key fields (`homeTeamId`, `competitionId`, `venueId`) default to `nil`.

**Rationale**:
- watchOS will never populate these fields (no library support)
- iOS can optionally populate when user selects from library
- Maintains backward compatibility with existing matches
- Text-based team names remain authoritative for display

### 2. Why Keep Text Entry Fallback?

**Decision**: Users can toggle between library selection and custom text entry.

**Rationale**:
- Quick one-off matches don't need library overhead
- Flexibility for ad-hoc games or guest teams
- Matches watchOS UX where only text entry exists
- Power users can use library; casual users can type

### 3. Why Name Caching?

**Decision**: Store `competitionName` and `venueName` in `CompletedMatchRecord` alongside IDs.

**Rationale**:
- Avoid JOIN queries for simple list displays
- Offline-first: names available even if library data deleted
- Snapshot semantics: match shows name at time of creation
- Database normalization at API layer, denormalization at client

### 4. Why Not Auto-Populate Team Names?

**Decision**: When team selected, we copy the name but don't bind to future changes.

**Rationale**:
- Match records are historical snapshots
- If team renamed later, old matches should keep original name
- Matches the database design (stores both ID and name)

---

## Database Schema Reference

The `matches` table already has these columns (verify with Supabase MCP):

```sql
-- Relevant columns in matches table
home_team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
home_team_name TEXT NOT NULL,
away_team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
away_team_name TEXT NOT NULL,
competition_id UUID REFERENCES competitions(id) ON DELETE SET NULL,
competition_name TEXT,
venue_id UUID REFERENCES venues(id) ON DELETE SET NULL,
venue_name TEXT,
```

**Note**: Foreign keys use `ON DELETE SET NULL` to preserve match history even if library entity deleted.

---

## Common Pitfalls to Avoid

1. **Don't forget to update `encode(to:)` in `CompletedMatch`** - encoding is needed for Connectivity sync
2. **Don't force-unwrap team IDs** - they are always optional
3. **Don't auto-update match records when team renamed** - matches are snapshots
4. **Don't break watchOS compatibility** - keep all fields optional with nil defaults
5. **Don't forget to clear team ID when switching to custom text entry**
6. **Update previews** - pass mock `teamStore` to all preview instances of `MatchSetupView`

---

## Completion Criteria

Phase 4 is complete when:
- [ ] Domain models extended with optional foreign key fields
- [ ] `CompletedMatch` decoder handles legacy payloads gracefully
- [ ] `TeamPickerSheet` implemented with search and empty state
- [ ] `MatchSetupView` has team picker buttons and text entry fallback
- [ ] Repository populates team IDs in Supabase payload
- [ ] SwiftData persists team IDs in `CompletedMatchRecord`
- [ ] Unit tests pass for team selection logic
- [ ] Database queries show matches linked to teams
- [ ] Manual testing confirms end-to-end flow works
- [ ] No regressions in existing match creation flow

---

## Timeline Estimate

| Task | Estimated Effort |
|------|------------------|
| Step 1: Domain Model Extensions | 2-3 hours |
| Step 2: Team Picker UI | 4-5 hours |
| Step 3: Testing & Validation | 2 hours |
| **Total** | **8-10 hours** |

---

## Next Steps After Phase 4

Once Phase 4 is complete:
1. Mark Phase 4 as ✅ COMPLETED in the plan
2. Move to Phase 5: Competition/Venue Match Setup Integration
3. Phase 5 will add competition and venue pickers using the same pattern

Phase 5 will be simpler than Phase 4 since the pattern is established. It will involve:
- Adding competition picker to match setup
- Adding venue picker to match setup
- Populating `competitionId`/`venueId` in the same way as `teamId`

---

## Questions?

If you encounter issues:
1. Reference the Team library files for existing patterns
2. Check `SupabaseMatchIngestService` payload structure - it already has team ID fields
3. Verify database schema with Supabase MCP: `DESCRIBE matches;`
4. Test with existing teams in the database

---

## Success Metrics

After Phase 4:
- Users can select teams from library in <2 taps
- Match records include team foreign keys when library used
- Database analytics can aggregate by team
- Text entry fallback still works for flexibility
- No breaking changes to existing matches
- watchOS compatibility maintained

Good luck! Phase 4 bridges the gap between library entities and match records, unlocking powerful analytics in future phases. 🚀
