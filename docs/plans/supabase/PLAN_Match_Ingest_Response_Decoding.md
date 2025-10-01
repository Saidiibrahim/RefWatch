# PLAN: Match Ingest Response Decoding Error

## Status: IN PROGRESS

**Date:** 2025-09-30
**Priority:** HIGH
**Related:** [HANDOFF_Match_Ingest_401_Investigation.md](./complete/HANDOFF_Match_Ingest_401_Investigation.md)

---

## Problem Summary

After successfully resolving the 401 authentication issue, the iOS client now receives a **200 OK** response from the `matches-ingest` edge function, but fails to decode the response with:

```
Supabase match push failed id=2F932DF8-EDA5-4B09-BF7C-E8CFECF8F7D0
error=The data couldn't be read because it isn't in the correct format.
```

### Evidence

**✅ Edge Function Success:**
```
"matches-ingest: Successfully ingested match {
  matchId: "2f932df8-eda5-4b09-bf7c-e8cfecf8f7d0",
  userId: "22fe9306-52cd-493f-830b-916a3c271371"
}"
```

**✅ HTTP 200 Response:**
```
"POST | 200 | https://muwuzfbtmqwvwacqnofc.supabase.co/functions/v1/matches-ingest"
```

**❌ iOS Decoding Failure:**
```swift
Match ingest decoding error: The data couldn't be read because it isn't in the correct format.
```

---

## Root Cause Hypothesis

The edge function returns a response in the format:
```typescript
{
  match_id: result.id,          // UUID string
  updated_at: updatedAt         // ISO8601 timestamp string
}
```

The iOS client expects:
```swift
struct SyncResult: Decodable {
  let matchId: UUID
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case matchId = "match_id"
    case updatedAt = "updated_at"
  }
}
```

**Potential Issues:**

1. **Date Format Mismatch:** The `updated_at` value from Postgres might not be in the exact ISO8601 format that Swift's `JSONDecoder.dateDecodingStrategy = .iso8601` expects
2. **PostgresJS Timestamp Serialization:** The `result.updated_at` from the Postgres query might be a Date object that doesn't serialize correctly
3. **Missing Fractional Seconds:** Swift's ISO8601 decoder may expect fractional seconds, but Postgres might not include them

---

## Investigation Steps

### 1. Check Actual Response Format

The edge function has been updated (version 13, pending deployment) to log the exact response:

```typescript
console.log("matches-ingest: Returning response", { response });
```

**Action Required:** Deploy version 13 and check edge function logs for the actual response format.

### 2. Verify iOS Decoder Configuration

Current decoder setup in [SupabaseMatchIngestService.swift:430-434](../../../RefZoneiOS/Core/Platform/Supabase/SupabaseMatchIngestService.swift#L430-L434):

```swift
static func makeDecoder() -> JSONDecoder {
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  return decoder
}
```

The `.iso8601` strategy in Swift is **strict** and expects:
- Format: `yyyy-MM-dd'T'HH:mm:ssZ` or `yyyy-MM-dd'T'HH:mm:ss.SSSZ`
- Must have 'Z' or timezone offset
- Fractional seconds are optional but must be exactly 3 digits if present

### 3. Test Date Format Conversion

Edge function date conversion logic (version 12/13):

```typescript
const updatedAt = result.updated_at instanceof Date
  ? result.updated_at.toISOString()
  : typeof result.updated_at === "string"
    ? result.updated_at
    : new Date(result.updated_at).toISOString();
```

JavaScript's `toISOString()` returns: `2025-09-30T09:16:42.448Z` (always has 3 fractional seconds)

---

## Proposed Solutions

### Option 1: Custom Date Decoding Strategy (RECOMMENDED)

Update the decoder to handle multiple date formats:

```swift
static func makeDecoder() -> JSONDecoder {
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let dateString = try container.decode(String.self)

    // Try ISO8601 with fractional seconds first
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
      return date
    }

    // Fall back to ISO8601 without fractional seconds
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: dateString) {
      return date
    }

    throw DecodingError.dataCorruptedError(
      in: container,
      debugDescription: "Cannot decode date from: \(dateString)"
    )
  }
  return decoder
}
```

### Option 2: Ensure Postgres Returns Correct Format

Modify the edge function SQL query to explicitly format the timestamp:

```typescript
const [row] = await tx`
  ...
  returning id, to_char(updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as updated_at;
`;
```

### Option 3: Debug Logging

Add temporary logging to see the actual response:

```swift
do {
  let response: HTTPResponse = try await supabaseClient.functionsClient.invoke(
    "matches-ingest",
    options: options
  )

  #if DEBUG
  if let responseString = String(data: response.data, encoding: .utf8) {
    AppLog.supabase.debug("Raw response: \(responseString, privacy: .public)")
  }
  #endif

  return try decoder.decode(SyncResult.self, from: response.data)
} catch {
  #if DEBUG
  AppLog.supabase.error("Decode error: \(error.localizedDescription, privacy: .public)")
  #endif
  throw error
}
```

---

## Action Plan

### Step 1: Deploy Edge Function Version 13 ✅ (Pending)

Edge function has been updated with response logging. Deploy to see actual format.

### Step 2: Add iOS Debug Logging

Update [SupabaseMatchIngestService.swift](../../../RefZoneiOS/Core/Platform/Supabase/SupabaseMatchIngestService.swift) to log raw response before decoding.

### Step 3: Analyze Logs

Run the iOS app, trigger a match save, and collect:
- Edge function log: "Returning response"
- iOS log: "Raw response"
- iOS log: "Decode error" with details

### Step 4: Implement Fix

Based on logs, implement either:
- Option 1: Custom date decoder (if date format is the issue)
- Option 2: Fix edge function response format
- Option 3: Change iOS model to use String instead of Date (temporary workaround)

---

## Files to Modify

1. **Edge Function:** [matches-ingest/index.ts](../../../RefZoneiOS/Core/Platform/Supabase/functions/matches-ingest/index.ts)
   - Status: Updated with logging (version 13, pending deployment)

2. **iOS Client:** [SupabaseMatchIngestService.swift](../../../RefZoneiOS/Core/Platform/Supabase/SupabaseMatchIngestService.swift)
   - [ ] Add raw response logging
   - [ ] Implement custom date decoding strategy if needed

---

## Success Criteria

- [ ] iOS app successfully decodes the edge function response
- [ ] Match saves complete without errors
- [ ] `SyncResult.updatedAt` contains the correct timestamp
- [ ] No retry loops or error messages in logs

---

## References

- Swift ISO8601DateFormatter: https://developer.apple.com/documentation/foundation/iso8601dateformatter
- JSONDecoder Date Strategies: https://developer.apple.com/documentation/foundation/jsondecoder/datadecodingstrategy
- JavaScript toISOString(): https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date/toISOString
- Previous Issue: [HANDOFF_Match_Ingest_401_Investigation.md](./complete/HANDOFF_Match_Ingest_401_Investigation.md)

## Progress Update (2025-09-30)

### Completed Work
- Added debug logging in `SupabaseMatchIngestService` to capture the raw response payload returned by the `matches-ingest` edge function before decoding. This gives immediate visibility into the response payload when failures occur.
- Swapped the ingestion decoder to a custom ISO-8601/Postgres tolerant strategy shared through `SupabaseDateParser`, allowing fractional seconds, missing fractional seconds, and Postgres-style offsets without tripping decoding errors.
- Introduced unit coverage (`SupabaseMatchIngestServiceTests`) to exercise the new decoder across the formats observed in Supabase logs.

### Outstanding Items
- Re-run the targeted test suite locally once sandbox restrictions are lifted—the inline decoder tests were added but the automated run could not complete inside the sandboxed CI environment.
- Perform an end-to-end ingest from the app to confirm the sync completes cleanly and that logging now provides useful diagnostics when issues surface.
