# Phase 5 Handoff: Competition & Venue Selection in Match Setup

**Status**: Completed
**Estimated Effort**: 4-6 hours (actual ~5 hours)
**Dependencies**: Phases 2, 3, and 4 (all completed)
**Created**: 2025-09-30

## Context

All prerequisite phases have been completed:
- ✅ Phase 1: Match history sync is working
- ✅ Phase 2: Competitions library fully implemented with Supabase sync
- ✅ Phase 3: Venues library fully implemented with Supabase sync
- ✅ Phase 4: Team selection integrated into match setup with foreign key support

Phase 5 completed the library integration by adding competition and venue pickers to the match setup flow, mirroring the pattern from Phase 4 for team selection.

## Objective

Enhanced the match setup flow to allow selecting competitions and venues from the library:
- Added optional competition picker
- Added optional venue picker
- Populated `Match.competitionId`, `Match.competitionName`, `Match.venueId`, `Match.venueName`
- Synced these fields to Supabase database
- Maintained backward compatibility (all fields optional)

## Outcome

- MatchSetupView now offers competition and venue pickers with empty-state messaging that mirrors the team picker UX.
- Selected competition and venue IDs/names flow through Match to Supabase, producing populated foreign keys in the `matches` table when chosen.
- MainTabView and MatchesTabView inject the new repositories so every setup entry point has consistent access to library data.
- Manual smoke checks confirmed optional flows (no selection, clearing selections) and the watch integration continues to work unchanged.

## Why This Matters

**Current State**: Phase 4 added team selection, but competition and venue are still missing.

**Desired State**: Complete library integration:
- Select competition for regulatory context (league, cup, friendly)
- Select venue for location tracking
- Database analytics can aggregate by competition or venue
- Rich metadata for match history displays

**Business Value**:
- Users can analyze performance by competition type
- Venue tracking enables location-based insights
- Professional referees can track assignments by league/competition
- Prepares for future features (competition standings, venue statistics)

## Architecture Overview

### Pattern Reuse from Phase 4

Phase 5 is essentially **copy-paste-adapt** from Phase 4's team picker implementation:

1. **Domain models**: Already extended in Phase 4 with `competitionId`, `venueId`, `competitionName`, `venueName`
2. **UI pattern**: Reuse `TeamPickerSheet` structure for `CompetitionPickerSheet` and `VenuePickerSheet`
3. **State management**: Same toggle between library selection and manual entry
4. **Repository**: Already wired to send these fields to Supabase

### What's Already Done (Phase 4)

Phase 4 completed the heavy lifting:
- ✅ Domain models extended with optional foreign keys
- ✅ `CompletedMatch` decoder handles optional fields
- ✅ `CompletedMatchRecord` has columns for all foreign keys
- ✅ `SwiftDataMatchHistoryStore` persists all fields
- ✅ `SupabaseMatchHistoryRepository.makeMatchBundleRequest()` includes all fields
- ✅ UI pattern established with team picker

### What Phase 5 Needs to Do

Phase 5 only needs to:
1. Create `CompetitionPickerSheet` (clone of `TeamPickerSheet`)
2. Create `VenuePickerSheet` (clone of `TeamPickerSheet`)
3. Add picker UI to `MatchSetupView` (clone team picker pattern)
4. Wire stores through view hierarchy
5. Test end-to-end

**Estimated effort is low because all infrastructure exists.**

---

## Implementation Plan

### Step 1: Create Competition Picker Sheet (1 hour)

**New File**: `RefZoneiOS/Features/Match/MatchSetup/CompetitionPickerSheet.swift`

**Implementation**: Clone `TeamPickerSheet.swift` and adapt for competitions.

```swift
import SwiftUI

/// Sheet for selecting a competition from the library
struct CompetitionPickerSheet: View {
    let competitionStore: CompetitionLibraryStoring
    let onSelect: (CompetitionRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var competitions: [CompetitionRecord] = []
    @State private var searchText = ""
    @State private var isLoading = false

    var filteredCompetitions: [CompetitionRecord] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return competitions
        }

        let lowercased = searchText.lowercased()
        return competitions.filter { competition in
            competition.name.lowercased().contains(lowercased) ||
            (competition.level?.lowercased().contains(lowercased) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading competitions...")
                } else if competitions.isEmpty {
                    emptyStateView
                } else {
                    competitionListView
                }
            }
            .navigationTitle("Select Competition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search competitions")
            .onAppear { loadCompetitions() }
        }
    }

    @ViewBuilder
    private var competitionListView: some View {
        List {
            if filteredCompetitions.isEmpty {
                ContentUnavailableView(
                    "No Competitions Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            } else {
                ForEach(filteredCompetitions) { competition in
                    Button {
                        onSelect(competition)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(competition.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if let level = competition.level {
                                Text(level)
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
            "No Competitions Yet",
            systemImage: "trophy",
            description: Text("Create competitions in Settings → Library → Competitions")
        )
    }

    private func loadCompetitions() {
        isLoading = true
        do {
            competitions = try competitionStore.loadAll()
        } catch {
            print("Failed to load competitions: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    CompetitionPickerSheet(
        competitionStore: InMemoryCompetitionLibraryStore(preloadedCompetitions: [
            CompetitionRecord(
                id: UUID(),
                name: "Premier League",
                level: "Professional",
                ownerSupabaseId: "test",
                lastModifiedAt: Date(),
                remoteUpdatedAt: nil,
                needsRemoteSync: false
            ),
            CompetitionRecord(
                id: UUID(),
                name: "FA Cup",
                level: "Professional",
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

**Key Adaptations from Team Picker**:
- Replace `teamStore` → `competitionStore`
- Replace `TeamRecord` → `CompetitionRecord`
- Replace `division` → `level` in display
- Empty state icon: `"trophy"` instead of `"person.3"`
- Empty state text: "No Competitions Yet"

---

### Step 2: Create Venue Picker Sheet (1 hour)

**New File**: `RefZoneiOS/Features/Match/MatchSetup/VenuePickerSheet.swift`

**Implementation**: Clone `TeamPickerSheet.swift` and adapt for venues.

```swift
import SwiftUI

/// Sheet for selecting a venue from the library
struct VenuePickerSheet: View {
    let venueStore: VenueLibraryStoring
    let onSelect: (VenueRecord) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var venues: [VenueRecord] = []
    @State private var searchText = ""
    @State private var isLoading = false

    var filteredVenues: [VenueRecord] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return venues
        }

        let lowercased = searchText.lowercased()
        return venues.filter { venue in
            venue.name.lowercased().contains(lowercased) ||
            (venue.city?.lowercased().contains(lowercased) ?? false) ||
            (venue.country?.lowercased().contains(lowercased) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading venues...")
                } else if venues.isEmpty {
                    emptyStateView
                } else {
                    venueListView
                }
            }
            .navigationTitle("Select Venue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search venues")
            .onAppear { loadVenues() }
        }
    }

    @ViewBuilder
    private var venueListView: some View {
        List {
            if filteredVenues.isEmpty {
                ContentUnavailableView(
                    "No Venues Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term")
                )
            } else {
                ForEach(filteredVenues) { venue in
                    Button {
                        onSelect(venue)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(venue.name)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if let city = venue.city, let country = venue.country {
                                Text("\(city), \(country)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let city = venue.city {
                                Text(city)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let country = venue.country {
                                Text(country)
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
            "No Venues Yet",
            systemImage: "building.2",
            description: Text("Create venues in Settings → Library → Venues")
        )
    }

    private func loadVenues() {
        isLoading = true
        do {
            venues = try venueStore.loadAll()
        } catch {
            print("Failed to load venues: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

// MARK: - Preview
#Preview {
    VenuePickerSheet(
        venueStore: InMemoryVenueLibraryStore(preloadedVenues: [
            VenueRecord(
                id: UUID(),
                name: "Wembley Stadium",
                city: "London",
                country: "England",
                latitude: nil,
                longitude: nil,
                ownerSupabaseId: "test",
                lastModifiedAt: Date(),
                remoteUpdatedAt: nil,
                needsRemoteSync: false
            ),
            VenueRecord(
                id: UUID(),
                name: "Emirates Stadium",
                city: "London",
                country: "England",
                latitude: nil,
                longitude: nil,
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

**Key Adaptations from Team Picker**:
- Replace `teamStore` → `venueStore`
- Replace `TeamRecord` → `VenueRecord`
- Display: `city, country` instead of `division`
- Empty state icon: `"building.2"` instead of `"person.3"`
- Empty state text: "No Venues Yet"
- Search includes name, city, and country

---

### Step 3: Update MatchSetupView (2-3 hours)

**File**: `RefZoneiOS/Features/Match/MatchSetup/MatchSetupView.swift`

#### 3.1 Add State Variables

Add after the existing team selection state:

```swift
// Competition selection state
@State private var selectedCompetition: CompetitionRecord?
@State private var showingCompetitionPicker = false
@State private var competitionName = ""

// Venue selection state
@State private var selectedVenue: VenueRecord?
@State private var showingVenuePicker = false
@State private var venueName = ""
```

#### 3.2 Inject Stores

Update the struct signature to include stores:

```swift
struct MatchSetupView: View {
    // Existing parameters...
    let teamStore: TeamLibraryStoring
    let competitionStore: CompetitionLibraryStoring  // Add this
    let venueStore: VenueLibraryStoring              // Add this

    // ... existing body
}
```

#### 3.3 Add Competition Picker Section

Add a new section after the Teams section:

```swift
// Add after Teams section
Section("Competition (Optional)") {
    Button {
        showingCompetitionPicker = true
    } label: {
        HStack {
            Text("Competition")
                .foregroundStyle(.primary)
            Spacer()
            Text(selectedCompetition?.name ?? competitionName.isEmpty ? "None" : competitionName)
                .foregroundStyle(selectedCompetition == nil && competitionName.isEmpty ? .secondary : .primary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    if selectedCompetition != nil {
        Button("Clear Selection") {
            selectedCompetition = nil
            competitionName = ""
        }
        .font(.caption)
        .foregroundStyle(.red)
    }
}
.headerProminence(.increased)
```

#### 3.4 Add Venue Picker Section

Add a new section after the Competition section:

```swift
// Add after Competition section
Section("Venue (Optional)") {
    Button {
        showingVenuePicker = true
    } label: {
        HStack {
            Text("Venue")
                .foregroundStyle(.primary)
            Spacer()
            Text(selectedVenue?.name ?? venueName.isEmpty ? "None" : venueName)
                .foregroundStyle(selectedVenue == nil && venueName.isEmpty ? .secondary : .primary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    if selectedVenue != nil {
        Button("Clear Selection") {
            selectedVenue = nil
            venueName = ""
        }
        .font(.caption)
        .foregroundStyle(.red)
    }
}
.headerProminence(.increased)
```

#### 3.5 Add Sheet Modifiers

Add after the existing team picker sheets:

```swift
.sheet(isPresented: $showingCompetitionPicker) {
    CompetitionPickerSheet(competitionStore: competitionStore) { competition in
        selectedCompetition = competition
        competitionName = competition.name
    }
}
.sheet(isPresented: $showingVenuePicker) {
    VenuePickerSheet(venueStore: venueStore) { venue in
        selectedVenue = venue
        venueName = venue.name
    }
}
```

#### 3.6 Update `configureMatch()` Method

Find the `configureMatch()` method and update it to populate competition and venue fields:

```swift
private func configureMatch() {
    // ... existing setup logic

    var match = Match(
        id: UUID(),
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        // ... other fields
    )

    // Populate team IDs (existing from Phase 4)
    match.homeTeamId = selectedHomeTeam?.id
    match.awayTeamId = selectedAwayTeam?.id

    // Populate competition fields (NEW)
    match.competitionId = selectedCompetition?.id
    match.competitionName = selectedCompetition?.name

    // Populate venue fields (NEW)
    match.venueId = selectedVenue?.id
    match.venueName = selectedVenue?.name

    model.configureMatch(match)
}
```

---

### Step 4: Wire Stores Through View Hierarchy (1 hour)

#### 4.1 Update `MatchesTabView`

**File**: `RefZoneiOS/Features/Matches/Views/MatchesTabView.swift`

Add parameters and pass to `MatchSetupView`:

```swift
struct MatchesTabView: View {
    // ... existing parameters
    let teamStore: TeamLibraryStoring
    let competitionStore: CompetitionLibraryStoring  // Add this
    let venueStore: VenueLibraryStoring              // Add this

    // ... body

    .sheet(isPresented: $showingMatchSetup) {
        MatchSetupView(
            model: matchSetupModel,
            teamStore: teamStore,
            competitionStore: competitionStore,  // Add this
            venueStore: venueStore,              // Add this
            onMatchConfigured: { /* ... */ }
        )
    }
}
```

#### 4.2 Update `MainTabView`

**File**: `RefZoneiOS/App/MainTabView.swift`

Pass stores to `MatchesTabView`:

```swift
struct MainTabView: View {
    // ... existing properties
    let teamStore: TeamLibraryStoring
    let competitionStore: CompetitionLibraryStoring
    let venueStore: VenueLibraryStoring

    var body: some View {
        TabView(selection: $selectedTab) {
            MatchesTabView(
                // ... existing parameters
                teamStore: teamStore,
                competitionStore: competitionStore,  // Add this
                venueStore: venueStore                // Add this
            )
            // ... other tabs
        }
    }
}
```

**Note**: `competitionStore` and `venueStore` already exist in `MainTabView` from Phases 2 & 3. Just ensure they're passed down.

#### 4.3 Update Preview

Update the `#Preview` at the bottom of `MatchSetupView`:

```swift
#Preview {
    MatchSetupView(
        model: MatchSetupViewModel(),
        teamStore: InMemoryTeamLibraryStore(),
        competitionStore: InMemoryCompetitionLibraryStore(),  // Add this
        venueStore: InMemoryVenueLibraryStore(),              // Add this
        onMatchConfigured: {}
    )
}
```

---

### Step 5: Testing & Validation (1 hour)

#### 5.1 Manual Testing Flow

**Test Case 1: Full Library Selection**
1. Open app → Matches tab → Add Match
2. Select home team from library
3. Select away team from library
4. Tap "Competition" → select competition
5. Tap "Venue" → select venue
6. Verify all names appear in match setup form
7. Start match → complete match
8. Query database: verify all foreign keys populated

**Test Case 2: Optional Fields**
1. Create match with teams only (no competition/venue)
2. Verify `competition_id` and `venue_id` are null in database
3. Create match with competition but no venue
4. Verify `competition_id` populated, `venue_id` null

**Test Case 3: Clear Selection**
1. Select competition
2. Tap "Clear Selection"
3. Verify competition cleared from form
4. Start match → verify `competition_id` is null

**Test Case 4: Empty State**
1. Open match setup with no competitions in library
2. Tap "Competition" → should see "No Competitions Yet" empty state
3. Same for venues

#### 5.2 Database Verification

Run this query via Supabase MCP to verify end-to-end:

```sql
-- Verify match has proper links to all library entities
SELECT
    m.id,
    m.started_at,
    m.home_team_name,
    m.home_team_id,
    ht.name as home_team_linked_name,
    m.away_team_name,
    m.away_team_id,
    at.name as away_team_linked_name,
    m.competition_name,
    m.competition_id,
    c.name as competition_linked_name,
    m.venue_name,
    m.venue_id,
    v.name as venue_linked_name,
    -- Verify foreign key integrity
    CASE
        WHEN m.competition_id IS NOT NULL AND c.id IS NULL THEN 'BROKEN'
        ELSE 'OK'
    END as competition_link_status,
    CASE
        WHEN m.venue_id IS NOT NULL AND v.id IS NULL THEN 'BROKEN'
        ELSE 'OK'
    END as venue_link_status
FROM matches m
LEFT JOIN teams ht ON m.home_team_id = ht.id
LEFT JOIN teams at ON m.away_team_id = at.id
LEFT JOIN competitions c ON m.competition_id = c.id
LEFT JOIN venues v ON m.venue_id = v.id
WHERE m.owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY m.started_at DESC
LIMIT 10;
```

Expected result:
- `competition_id` and `venue_id` populated when selected
- Foreign key joins resolve to actual records
- Link status is 'OK' for all records

#### 5.3 Unit Tests (Optional)

If time permits, add tests to verify:

```swift
@Test("Match includes competition ID when selected")
func matchIncludesCompetitionId() {
    let competition = CompetitionRecord(
        id: UUID(),
        name: "Premier League",
        level: nil,
        ownerSupabaseId: "test",
        lastModifiedAt: Date(),
        remoteUpdatedAt: nil,
        needsRemoteSync: false
    )

    var match = Match.createDefault()
    match.competitionId = competition.id
    match.competitionName = competition.name

    #expect(match.competitionId == competition.id)
    #expect(match.competitionName == "Premier League")
}

@Test("Match includes venue ID when selected")
func matchIncludesVenueId() {
    let venue = VenueRecord(
        id: UUID(),
        name: "Wembley Stadium",
        city: "London",
        country: "England",
        latitude: nil,
        longitude: nil,
        ownerSupabaseId: "test",
        lastModifiedAt: Date(),
        remoteUpdatedAt: nil,
        needsRemoteSync: false
    )

    var match = Match.createDefault()
    match.venueId = venue.id
    match.venueName = venue.name

    #expect(match.venueId == venue.id)
    #expect(match.venueName == "Wembley Stadium")
}
```

---

## Key Design Decisions

### 1. Why Optional (Not Required)?

**Decision**: Competition and venue are optional, not required.

**Rationale**:
- Not every match has a formal competition (pickup games, training)
- Not every match has a specific venue (neutral sites, traveling)
- Flexibility for casual users vs professional referees
- Matches watchOS UX where these fields don't exist

### 2. Why Name Caching?

**Decision**: Store both ID and name in `Match` model.

**Rationale**:
- Match is a historical snapshot
- If competition/venue renamed later, old matches keep original name
- Offline display doesn't require JOIN queries
- Database normalization at API layer, denormalization at client

### 3. Why No Manual Text Entry?

**Decision**: Unlike teams, no manual text entry fallback for competition/venue.

**Rationale**:
- Teams have natural fallback (opponent name always needed)
- Competition/venue are truly optional metadata
- Simpler UX: select from library or leave empty
- Can always add "Other" placeholder record to library if needed

### 4. Why Section Headers "Optional"?

**Decision**: Section headers explicitly say "(Optional)".

**Rationale**:
- Clear UX: users know they can skip these fields
- Reduces anxiety about "required" fields
- Matches iOS design patterns (similar to Contacts app)

---

## Common Pitfalls to Avoid

1. **Don't forget to pass stores down the view hierarchy** - trace from `RefZoneiOSApp` → `MainTabView` → `MatchesTabView` → `MatchSetupView`
2. **Don't reuse team picker state variables** - create separate state for competition and venue
3. **Don't forget to update previews** - all preview instances need mock stores
4. **Don't make competition/venue required** - keep them optional
5. **Don't forget to handle nil gracefully** - display "None" when no selection
6. **Update both `competitionId` and `competitionName`** - domain model needs both fields
7. **Clear selection should set both ID and name to nil** - avoid orphaned state

---

## Completion Criteria

Phase 5 is complete when:
- [x] `CompetitionPickerSheet` created and compiling
- [x] `VenuePickerSheet` created and compiling
- [x] `MatchSetupView` has competition and venue sections
- [x] Stores wired through view hierarchy
- [x] Can select competition and venue from library
- [x] Can clear selection and leave fields empty
- [x] Empty states show when no library data
- [x] Database shows foreign keys populated when selected
- [x] Database shows nulls when not selected
- [x] Manual testing confirms end-to-end flow works
- [x] No regressions in existing team selection flow

---

## Timeline Estimate

| Task | Estimated Effort |
|------|------------------|
| Step 1: CompetitionPickerSheet | 1 hour |
| Step 2: VenuePickerSheet | 1 hour |
| Step 3: Update MatchSetupView | 2-3 hours |
| Step 4: Wire Stores | 1 hour |
| Step 5: Testing | 1 hour |
| **Total** | **6-7 hours** |

**Note**: Estimate is conservative. If you're familiar with Phase 4's team picker, this could be done in 4-5 hours.

---

## Reference Files

**Team Picker (Phase 4 - your template)**:
- `RefZoneiOS/Features/Match/MatchSetup/TeamPickerSheet.swift` - Clone this for competition/venue pickers
- `RefZoneiOS/Features/Match/MatchSetup/MatchSetupView.swift` - Study the team picker pattern

**Library Stores (Phases 2 & 3)**:
- `RefZoneiOS/Core/Protocols/CompetitionLibraryStoring.swift` - Protocol definition
- `RefZoneiOS/Core/Protocols/VenueLibraryStoring.swift` - Protocol definition
- `RefZoneiOS/Core/Persistence/InMemoryCompetitionLibraryStore.swift` - For previews
- `RefZoneiOS/Core/Persistence/InMemoryVenueLibraryStore.swift` - For previews

**Domain Models (Phase 4)**:
- `RefWatchCore/Sources/RefWatchCore/Models/Match.swift` - Already has optional fields
- `RefWatchCore/Sources/RefWatchCore/Models/CompletedMatch.swift` - Already handles encoding/decoding
- `RefZoneiOS/Core/Persistence/SwiftData/CompletedMatchRecord.swift` - Already has columns

---

## Success Metrics

After Phase 5:
- Users can select competition and venue in <2 taps
- Match records include full library metadata when selected
- Database analytics can aggregate by competition or venue
- Professional referees can track league/cup assignments
- All library features (teams, competitions, venues) fully integrated
- No breaking changes to existing flows
- watchOS compatibility maintained (optional fields)

---

## Next Steps After Phase 5

Once Phase 5 is complete:
1. Mark Phase 5 as ✅ COMPLETED in the plan
2. All planned library features are now implemented
3. Consider future enhancements:
   - Competition standings/leaderboards
   - Venue maps/directions
   - Recent selections (quick picks)
   - Bulk match entry with same competition/venue

---

## Questions?

If you encounter issues:
1. Reference `TeamPickerSheet.swift` from Phase 4 - it's your blueprint
2. Check that `competitionStore` and `venueStore` exist in `MainTabView` (from Phases 2 & 3)
3. Verify database schema with Supabase MCP: `DESCRIBE matches;`
4. Test with existing competitions/venues in the database

---

## Implementation Checklist

Use this checklist to track progress:

- [x] Create `CompetitionPickerSheet.swift`
  - [x] Clone from `TeamPickerSheet.swift`
  - [x] Adapt for `CompetitionRecord` and `competitionStore`
  - [x] Update icons, labels, empty states
  - [x] Add preview with sample data

- [x] Create `VenuePickerSheet.swift`
  - [x] Clone from `TeamPickerSheet.swift`
  - [x] Adapt for `VenueRecord` and `venueStore`
  - [x] Update icons, labels, empty states
  - [x] Add preview with sample data

- [x] Update `MatchSetupView.swift`
  - [x] Add competition state variables
  - [x] Add venue state variables
  - [x] Inject `competitionStore` parameter
  - [x] Inject `venueStore` parameter
  - [x] Add competition picker section
  - [x] Add venue picker section
  - [x] Add competition sheet modifier
  - [x] Add venue sheet modifier
  - [x] Update `configureMatch()` to populate IDs
  - [x] Update preview with mock stores

- [x] Update `MatchesTabView.swift`
  - [x] Add `competitionStore` parameter
  - [x] Add `venueStore` parameter
  - [x] Pass stores to `MatchSetupView`

- [x] Update `MainTabView.swift`
  - [x] Verify `competitionStore` exists
  - [x] Verify `venueStore` exists
  - [x] Pass stores to `MatchesTabView`

- [x] Testing
  - [x] Manual test: full library selection
  - [x] Manual test: optional fields (leave empty)
  - [x] Manual test: clear selection
  - [x] Manual test: empty state
  - [x] Database verification query
  - [x] Unit tests (optional)

- [x] Final verification
  - [x] All previews compile
  - [x] No compiler warnings
  - [x] Database foreign keys populated
  - [x] No regressions in team selection

---

Good luck! Phase 5 is the final piece of the library puzzle. Once complete, users will have a fully integrated library system for teams, competitions, and venues. 🚀
