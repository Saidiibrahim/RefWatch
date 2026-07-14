# Glossary

- **Match Face**: Visual layout rendered inside `TimerView` showing match state.
- **Period Time Remaining**: Countdown for current period; resets each half.
- **Stoppage Time**: Additional time added for pauses or penalties.
- **Penalty Window**: Time interval during which penalties remain active.
- **Assistant Feed**: Aggregated AI responses shown in the Assistant tab.
- **Backend Sync**: Offline-first synchronization from iOS through the authenticated Cloudflare Worker to PlanetScale Postgres.
- **Clerk Subject**: String authentication identity from a verified Clerk session token; it is not an internal app UUID.
- **App User ID**: Internal UUID returned by `/api/me` and used by the Worker for owner-scoped persistence.
- **Legacy Supabase**: Source provider and contract/migration evidence retained temporarily for data migration and rollback; not the target architecture.
- **TimerFaceStyle**: Enum representing watch timer face options (`standard`, etc.).
- **MatchHistoryEntry**: Model encapsulating a completed match summary.
