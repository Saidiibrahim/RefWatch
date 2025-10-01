# Phase 3 Handoff: Venues Library Implementation

**Status**: ✅ COMPLETED
**Actual Effort**: ~14 hours
**Completed**: 2025-09-30
**Dependencies**: None (Phase 2 provides reference implementation)

## Context

Phases 1 and 2 have been completed:
- ✅ Phase 1: Match history sync is now working with manual sync triggers
- ✅ Phase 2: Competitions library is fully implemented with Supabase sync

Phase 3 will implement the Venues library, which is nearly identical to the Competitions implementation. You can use the Competition files as a template and adapt them for Venues.

## Objective

Implement a complete CRUD + Supabase sync stack for managing venue records. This will allow users to:
- Create/edit/delete venues (stadiums, fields, facilities)
- Store venues locally in SwiftData
- Sync venues bidirectionally with Supabase
- Search venues by name, city, or country
- Use venues in match setup (Phase 5)

## Reference Implementation

**Use Phase 2 as your blueprint.** The Competition implementation is located at:

### Models
- `RefZoneiOS/Core/Models/Competition.swift` → adapt to `Venue.swift`
- `RefZoneiOS/Core/Persistence/SwiftData/CompetitionRecord.swift` → adapt to `VenueRecord.swift`

### Persistence
- `RefZoneiOS/Core/Protocols/CompetitionLibraryStoring.swift` → adapt to `VenueLibraryStoring.swift`
- `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataCompetitionLibraryStore.swift` → adapt to `SwiftDataVenueLibraryStore.swift`
- `RefZoneiOS/Core/Persistence/InMemoryCompetitionLibraryStore.swift` → adapt to `InMemoryVenueLibraryStore.swift`

### Supabase Integration
- `RefZoneiOS/Core/Platform/Supabase/SupabaseCompetitionLibraryAPI.swift` → adapt to `SupabaseVenueLibraryAPI.swift`
- `RefZoneiOS/Core/Platform/Supabase/SupabaseCompetitionLibraryRepository.swift` → adapt to `SupabaseVenueLibraryRepository.swift`
- `RefZoneiOS/Core/Platform/Supabase/SupabaseCompetitionSyncBacklogStore.swift` → adapt to `SupabaseVenueSyncBacklogStore.swift`

### UI
- `RefZoneiOS/Features/Library/Views/CompetitionsListView.swift` → adapt to `VenuesListView.swift`
- `RefZoneiOS/Features/Library/Views/CompetitionEditorView.swift` → adapt to `VenueEditorView.swift`

## Key Differences: Competition → Venue

When adapting the Competition files, make these changes:

### 1. Domain Model Fields

**Competition** has:
```swift
var name: String
var level: String?
```

**Venue** should have:
```swift
var name: String          // Required (e.g., "Wembley Stadium")
var city: String?         // Optional (e.g., "London")
var country: String?      // Optional (e.g., "England")
var latitude: Double?     // Optional (for future map integration)
var longitude: Double?    // Optional (for future map integration)
```

### 2. Database Table Name

- Competitions use: `competitions` table
- Venues use: `venues` table

### 3. UserDefaults Keys

Update the backlog store key from:
```swift
private let key = "com.refzone.supabase.competitionlibrary.pendingdeletes"
```

To:
```swift
private let key = "com.refzone.supabase.venuelibrary.pendingdeletes"
```

### 4. Sync Status Component Name

Update notification userInfo from:
```swift
"component": "competition_library"
```

To:
```swift
"component": "venue_library"
```

### 5. UI Icons and Labels

- Competition icon: `"trophy"`
- Venue icon: `"building.2"`

## Implementation Checklist

### Step 1: Core Models (1-2 hours)
- [ ] Create `RefZoneiOS/Core/Models/Venue.swift`
  - Include: `id`, `name`, `city`, `country`, `latitude`, `longitude`, `ownerId`, `createdAt`, `updatedAt`
  - Make it `Identifiable`, `Codable`, `Hashable`, `Sendable`
  - Add initializer with defaults
  - Add conversion helper: `init(from record: VenueRecord)`

- [ ] Create `RefZoneiOS/Core/Persistence/SwiftData/VenueRecord.swift`
  - Annotate with `@Model`
  - Mark `id` with `@Attribute(.unique)`
  - Include sync metadata: `ownerSupabaseId`, `lastModifiedAt`, `remoteUpdatedAt`, `needsRemoteSync`

### Step 2: Persistence Layer (2-3 hours)
- [ ] Create `RefZoneiOS/Core/Protocols/VenueLibraryStoring.swift`
  - Methods: `loadAll()`, `search(query:)`, `create()`, `update()`, `delete()`, `wipeAllForLogout()`
  - Include `changesPublisher: AnyPublisher<[VenueRecord], Never>`

- [ ] Create `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataVenueLibraryStore.swift`
  - Implement all protocol methods
  - Use `FetchDescriptor` with `#Predicate` for search
  - Search should match name, city, OR country (case-insensitive)
  - Post changes via `changesPublisher` after mutations
  - Require signed-in user via `auth.currentUserId`

- [ ] Create `RefZoneiOS/Core/Persistence/InMemoryVenueLibraryStore.swift`
  - In-memory array of `VenueRecord`
  - Implement same protocol for testing/previews
  - Include `preloadedVenues` initializer parameter

### Step 3: Supabase Integration (4-5 hours)
- [ ] Create `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueLibraryAPI.swift`
  - Protocol: `SupabaseVenueLibraryServing`
  - Methods: `fetchVenues(ownerId:updatedAfter:)`, `syncVenue(_:)`, `deleteVenue(venueId:)`
  - DTOs: `VenueRowDTO`, `VenueUpsertDTO`, `VenueResponseDTO`
  - Query from `venues` table
  - Select: `"id, owner_id, name, city, country, latitude, longitude, created_at, updated_at"`

- [ ] Create `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueSyncBacklogStore.swift`
  - Protocol: `VenueLibrarySyncBacklogStoring`
  - UserDefaults-backed persistence
  - Key: `"com.refzone.supabase.venuelibrary.pendingdeletes"`

- [ ] Create `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueLibraryRepository.swift`
  - Conform to `VenueLibraryStoring`
  - Wrap `SwiftDataVenueLibraryStore`
  - Implement queue-based sync (push/pull)
  - Handle auth state changes (wipe on sign-out)
  - Use cursor-based incremental sync with `remoteCursor: Date?`
  - Post sync status notifications

### Step 4: UI Layer (3-4 hours)
- [ ] Create `RefZoneiOS/Features/Library/Views/VenuesListView.swift`
  - Searchable list of venues
  - Empty state: `"No Venues"` with `"building.2"` icon
  - Search by name, city, or country
  - Swipe-to-delete
  - Toolbar: Add button, EditButton
  - Sheet presentation for editor

- [ ] Create `RefZoneiOS/Features/Library/Views/VenueEditorView.swift`
  - Form sections:
    - **Name** (required, max 100 chars)
    - **City** (optional, max 100 chars)
    - **Country** (optional, max 100 chars)
    - **Coordinates** (optional, readonly for now - future: map picker)
  - Validation: name is required
  - Navigation title: "New Venue" or "Edit Venue"
  - Save/Cancel buttons

### Step 5: Integration (2-3 hours)
- [ ] Update `RefZoneiOS/App/RefZoneiOSApp.swift`
  - Add `VenueRecord.self` to SwiftData schema
  - Create `swiftVenueStore = SwiftDataVenueLibraryStore(container:auth:)`
  - Create `venueStore = SupabaseVenueLibraryRepository(store:authStateProvider:)`
  - Add property: `private let venueStore: VenueLibraryStoring`
  - Pass to `MainTabView`

- [ ] Update `RefZoneiOS/App/MainTabView.swift`
  - Add parameter: `let venueStore: VenueLibraryStoring`
  - Pass to `SettingsTabView`
  - Update preview

- [ ] Update `RefZoneiOS/Features/Settings/Views/SettingsTabView.swift`
  - Add parameter: `var venueStore: VenueLibraryStoring? = nil`
  - Update initializer
  - Pass to `LibrarySettingsView`

- [ ] Update `RefZoneiOS/Features/Settings/Views/LibrarySettingsView.swift`
  - Add parameter: `let venueStore: VenueLibraryStoring`
  - Replace "Venues (coming soon)" with:
    ```swift
    NavigationLink { VenuesListView(store: venueStore) } label: {
        Label("Venues", systemImage: "building.2")
    }
    ```
  - Update preview

## Testing Strategy

### Unit Tests (Optional but Recommended)
Create test files following the pattern:
- `RefZoneiOSTests/SwiftDataVenueLibraryStoreTests.swift` - CRUD operations
- `RefZoneiOSTests/SupabaseVenueLibraryRepositoryTests.swift` - Sync behavior
- `RefZoneiOSTests/SupabaseVenueLibraryAPITests.swift` - HTTP mocking

### Manual Testing
1. **Create Flow**:
   - Settings → Library → Venues → Add
   - Enter: Name="Emirates Stadium", City="London", Country="England"
   - Save → verify appears in list

2. **Edit Flow**:
   - Tap venue → modify name → Save
   - Verify changes persist

3. **Delete Flow**:
   - Swipe-to-delete → confirm deletion
   - Verify removed from list

4. **Search**:
   - Create multiple venues
   - Search by name, city, country
   - Verify filtering works

5. **Supabase Sync** (requires database access):
   - Create venue → verify in Supabase `venues` table
   - Verify `owner_id`, `created_at`, `updated_at` populated
   - Test offline: create venue → go offline → verify queued
   - Go online → verify syncs

### Database Verification (Supabase MCP)

Run these queries to validate:

```sql
-- Check venue creation
SELECT id, name, city, country, owner_id, created_at, updated_at
FROM venues
WHERE owner_id = '22fe9306-52cd-493f-830b-916a3c271371'
ORDER BY created_at DESC;

-- Verify coordinates (if populated)
SELECT name, city, latitude, longitude
FROM venues
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Check for orphaned venues
SELECT COUNT(*) FROM venues WHERE owner_id NOT IN (SELECT id FROM auth.users);
```

## Common Pitfalls to Avoid

1. **Don't forget to add `VenueRecord` to schema** in `RefZoneiOSApp.swift`
2. **Update all UserDefaults keys** (don't reuse competition keys)
3. **Search should be case-insensitive** (use `.lowercased()`)
4. **Handle optional fields properly** (city, country, coordinates can be nil)
5. **Update notification component name** to `"venue_library"`
6. **Use correct icon** (`"building.2"` not `"trophy"`)
7. **Sign-out should wipe venues** (implement `wipeAllForLogout()`)

## Completion Criteria

Phase 3 is complete when:
- [x] All files created and compiling
- [x] Venues appear in Settings → Library
- [x] Can create, edit, delete venues
- [x] Search works for name, city, country
- [x] Venues sync to Supabase database
- [x] Sign-out clears local venues
- [x] No "coming soon" placeholder for venues

## Implementation Summary

Phase 3 was successfully completed with all 14 files created/modified:

**Created Files (10)**:
1. `RefZoneiOS/Core/Models/Venue.swift`
2. `RefZoneiOS/Core/Persistence/SwiftData/VenueRecord.swift`
3. `RefZoneiOS/Core/Protocols/VenueLibraryStoring.swift`
4. `RefZoneiOS/Core/Persistence/SwiftData/SwiftDataVenueLibraryStore.swift`
5. `RefZoneiOS/Core/Persistence/InMemoryVenueLibraryStore.swift`
6. `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueLibraryAPI.swift`
7. `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueSyncBacklogStore.swift`
8. `RefZoneiOS/Core/Platform/Supabase/SupabaseVenueLibraryRepository.swift`
9. `RefZoneiOS/Features/Library/Views/VenuesListView.swift`
10. `RefZoneiOS/Features/Library/Views/VenueEditorView.swift`

**Modified Files (4)**:
1. `RefZoneiOS/App/RefZoneiOSApp.swift` - Added VenueRecord to schema and wired repository
2. `RefZoneiOS/App/MainTabView.swift` - Added venueStore parameter
3. `RefZoneiOS/Features/Settings/Views/SettingsTabView.swift` - Added venueStore parameter
4. `RefZoneiOS/Features/Settings/Views/LibrarySettingsView.swift` - Replaced "coming soon" with VenuesListView

All implementation followed the Competition library pattern exactly, ensuring consistency and maintainability.

## Next Steps After Phase 3

Once Phase 3 is complete:
1. Mark Phase 3 as ✅ COMPLETED in the plan
2. Move to Phase 4: Team Selection Integration
3. Phase 4 will extend domain models to link teams/competitions/venues to matches

## Questions?

If you encounter issues:
1. Reference the Competition implementation (Phase 2) - it's your template
2. Check the Supabase database schema for the `venues` table structure
3. Look at existing Team library files for additional patterns

## Estimated Timeline

- Step 1 (Models): 1-2 hours
- Step 2 (Persistence): 2-3 hours
- Step 3 (Supabase): 4-5 hours
- Step 4 (UI): 3-4 hours
- Step 5 (Integration): 2-3 hours
- **Total**: 12-17 hours

Good luck! The hardest part is done (Phase 2). Phase 3 is mostly copy-paste-adapt. 🚀