# Handoff Summary: Match Ingest 401 Error Investigation

## Status: ✅ RESOLVED

**Date:** 2025-09-30
**Issue:** Signed-in users cannot save completed matches to Supabase edge function
**Error:** Edge Function returns 401 Unauthorized despite JWT verification enabled
**Resolution:** Fixed edge function to pass JWT explicitly to `getUser()` method

**Follow-up Issue:** [PLAN_Match_Ingest_Response_Decoding.md](./PLAN_Match_Ingest_Response_Decoding.md)

---

## Problem Summary

After enabling JWT verification on the `matches-ingest` edge function and removing iOS anon key fallback logic, the 401 errors **persist**. The Supabase platform successfully validates the JWT (confirmed by `auth_user` appearing in logs), but the edge function code receives an **empty Authorization header**.

### Key Evidence

From the latest edge function invocation logs:

```json
"authorization": []  // ❌ EMPTY - This is the root cause
```

But the JWT is validated by Supabase:
```json
"auth_user": "22fe9306-52cd-493f-830b-916a3c271371"  // ✅ User authenticated
```

This indicates a **mismatch between Supabase's platform-level auth and the edge function's request headers**.

---

## What We Fixed (But Didn't Solve the Issue)

### ✅ Fix 1: Enabled JWT Verification
- **File:** Supabase Dashboard → Edge Functions → matches-ingest
- **Action:** Enabled "Verify JWT with legacy secret"
- **Result:** Supabase now validates JWTs at the platform level
- **Verification:** Deployment version 11 shows `verify_jwt: true`

### ✅ Fix 2: Removed iOS Anon Key Fallback
- **File:** [SupabaseClientProvider.swift:367-390](../../../RefZoneiOS/Core/Platform/Supabase/SupabaseClientProvider.swift#L367-L390)
- **Change:** Removed fallback to anon key when session fetch fails
- **Impact:** iOS client now clears auth token instead of silently using anon key

### ✅ Fix 3: Simplified Edge Function Auth Logic
- **File:** [matches-ingest/index.ts:24-61](../../../RefZoneiOS/Core/Platform/Supabase/functions/matches-ingest/index.ts#L24-L61)
- **Change:** Simplified auth checks since JWT verification is now platform-level
- **Deployed:** Version 11 (active)

---

## Root Cause Analysis

### Issue: Supabase Swift SDK May Not Send Authorization Header to Edge Functions

**Evidence from Supabase Swift SDK Documentation:**

All test snapshots for `FunctionsClient.invoke()` show requests using the `apikey` header (lowercase), **NOT** an `Authorization: Bearer <token>` header:

```bash
# From Supabase Swift SDK tests
curl \
  --request POST \
  --header "apikey: supabase.anon.key" \  # ❌ Uses apikey, not Authorization
  --header "x-client-info: functions-swift/x.y.z" \
  "http://localhost:5432/functions/v1/hello-world"
```

Compare this to authenticated user API calls which DO use Authorization:

```bash
# From Auth API tests
curl \
  --header "Apikey: dummy.api.key" \
  --header "Authorization: Bearer accesstoken" \  # ✅ Authorization header present
  --header "X-Client-Info: gotrue-swift/x.y.z" \
  "http://localhost:54321/auth/v1/user"
```

### Current Implementation Problem

In [SupabaseMatchIngestService.swift:312-332](../../../RefZoneiOS/Core/Platform/Supabase/SupabaseMatchIngestService.swift#L312-L332):

```swift
func ingestMatchBundle(_ request: MatchBundleRequest) async throws -> SyncResult {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else { throw APIError.unsupportedClient }

    let payload = try encoder.encode(request)
    let options = FunctionInvokeOptions(
      method: .post,
      headers: [
        "Content-Type": "application/json",
        "Idempotency-Key": request.match.id.uuidString,
        "X-RefWatch-Client": "ios"
      ],  // ❌ No Authorization header in custom headers
      body: payload
    )

    return try await supabaseClient.functionsClient.invoke(
      "matches-ingest",
      options: options,
      decoder: decoder
    )
}
```

**The Problem:**
1. We call `clientProvider.authorizedClient()` which calls `refreshFunctionAuth()`
2. `refreshFunctionAuth()` calls `functionsClient.setAuth(token:)` with the user's access token
3. **BUT** when `functionsClient.invoke()` is called, the Swift SDK may not be including this token in the request headers
4. The edge function receives an empty `authorization` array

---

## Hypothesis: SDK Version or API Mismatch

The Supabase Swift SDK's `FunctionsClient` may have changed how it handles auth tokens between versions, or there may be a specific API for authenticated function calls that we're not using.

### Possible Solutions to Investigate:

#### Option 1: Manually Add Authorization Header
```swift
let session = try await supabaseClient.auth.session
let token = session.accessToken

let options = FunctionInvokeOptions(
  method: .post,
  headers: [
    "Authorization": "Bearer \(token)",  // Explicitly add Authorization header
    "Content-Type": "application/json",
    "Idempotency-Key": request.match.id.uuidString,
    "X-RefWatch-Client": "ios"
  ],
  body: payload
)
```

#### Option 2: Check SDK Version and API
- Current SDK: `supabase-swift/2.32.0` (from user agent in logs)
- Review SDK release notes for breaking changes to FunctionsClient auth
- Check if there's a different method for authenticated function invocations

#### Option 3: Use Service Role Key (NOT RECOMMENDED for client)
- This would bypass RLS and user auth entirely
- Only mentioned for completeness; should not be used in production iOS app

---

## Testing Evidence

### Xcode Logs
```
Functions auth updated with session token prefix=eyJhbGciOiJIUzI1NiIs
Authorized Supabase client ready
Supabase match push retry scheduled id=E68BB3EF-32C3-4BB8-BBBE-EDDD9F465B2C attempt=1 delay=5.000000s
Supabase match push failed id=E68BB3EF-32C3-4BB8-BBBE-EDDD9F465B2C error=Edge Function returned a non-2xx status code: 401
```

- ✅ Session token is retrieved successfully
- ✅ Client is marked as "Authorized"
- ❌ Edge function still returns 401

### Edge Function Invocation Metadata
```json
{
  "deployment_id": "muwuzfbtmqwvwacqnofc_f649fb40-62a3-43de-bb7d-c1dbc381e937_11",
  "jwt": [{
    "apikey": [{"apikey": [{"hash": "P3eNd-dS7ci0ng2ziV86-PYGix0T9blo8zPWRiWdVWc"}]}],
    "authorization": []  // ❌ EMPTY
  }],
  "auth_user": "22fe9306-52cd-493f-830b-916a3c271371"  // ✅ User authenticated by platform
}
```

---

## Next Steps for Investigation

### 1. Verify Authorization Header Injection (HIGH PRIORITY)
```swift
// Add this temporary debugging code to SupabaseMatchIngestService.swift
func ingestMatchBundle(_ request: MatchBundleRequest) async throws -> SyncResult {
    let client = try await clientProvider.authorizedClient()
    guard let supabaseClient = client as? SupabaseClient else { throw APIError.unsupportedClient }

    // DEBUG: Log current auth state
    do {
        let session = try await supabaseClient.auth.session
        print("🔍 DEBUG: Current session token prefix: \(String(session.accessToken.prefix(20)))")
    } catch {
        print("🔍 DEBUG: Failed to get session: \(error)")
    }

    // Try manually adding Authorization header
    let session = try await supabaseClient.auth.session
    let options = FunctionInvokeOptions(
      method: .post,
      headers: [
        "Authorization": "Bearer \(session.accessToken)",  // ✅ Explicit header
        "Content-Type": "application/json",
        "Idempotency-Key": request.match.id.uuidString,
        "X-RefWatch-Client": "ios"
      ],
      body: try encoder.encode(request)
    )

    return try await supabaseClient.functionsClient.invoke(
      "matches-ingest",
      options: options,
      decoder: decoder
    )
}
```

### 2. Review Supabase Swift SDK Source Code
- Check `FunctionsClient.swift` implementation for how `setAuth()` affects `invoke()`
- Look for any middleware or interceptor that should add Authorization headers
- Verify if there's a bug or breaking change in v2.32.0

### 3. Test with Minimal Reproduction
Create a simple test case:
```swift
let supabase = SupabaseClient(...)
let session = try await supabase.auth.session
supabase.functions.setAuth(token: session.accessToken)

let response = try await supabase.functions.invoke(
    "matches-ingest",
    options: FunctionInvokeOptions(method: .post, body: testData)
)
// Check if Authorization header is present in request
```

### 4. Check Supabase Dashboard Edge Function Settings
- Verify JWT verification is truly enabled (should see in function details)
- Check if there are any CORS or security policies blocking headers
- Review function logs for any JWT validation error messages

---

## Files Modified

1. **iOS Client:**
   - [SupabaseClientProvider.swift](../../../RefZoneiOS/Core/Platform/Supabase/SupabaseClientProvider.swift) - Removed anon key fallback
   - [SupabaseMatchIngestService.swift](../../../RefZoneiOS/Core/Platform/Supabase/SupabaseMatchIngestService.swift) - May need Authorization header

2. **Edge Function:**
   - [matches-ingest/index.ts](../../../RefZoneiOS/Core/Platform/Supabase/functions/matches-ingest/index.ts) - Simplified auth (version 11 deployed)

3. **Supabase Configuration:**
   - Edge Function JWT verification: ✅ ENABLED
   - Deployment version: 11
   - Status: ACTIVE

---

## References

- [Supabase Edge Functions Auth Docs](https://supabase.com/docs/guides/functions/auth)
- [Supabase Swift SDK GitHub](https://github.com/supabase/supabase-swift)
- Edge Function Logs: Supabase Dashboard → Functions → matches-ingest → Logs
- Test User ID: `22fe9306-52cd-493f-830b-916a3c271371`

---

## ✅ RESOLUTION (2025-09-30)

### Root Cause Identified

The issue was **NOT** with the Supabase Swift SDK - the Authorization header was being sent correctly. The problem was in the **edge function implementation**.

**Key Finding from Logs:**
```json
"jwt": [{
  "authorization": [{
    "payload": [{
      "subject": "22fe9306-52cd-493f-830b-916a3c271371",
      "role": "authenticated"
    }]
  }]
}]
```

The JWT **was** being sent and validated by the Supabase platform, but the edge function error was:
```
"matches-ingest: Failed to extract user from validated JWT { error: \"Auth session missing!\" }"
```

### The Bug

In [matches-ingest/index.ts:36-47](../../../RefZoneiOS/Core/Platform/Supabase/functions/matches-ingest/index.ts#L36-L47), we were creating a Supabase client and calling `supabase.auth.getUser()` **without a parameter**, which tried to get the user from the session. But in edge functions, there is no session - we need to pass the JWT explicitly.

**Broken Code:**
```typescript
const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  global: { headers: { Authorization: authHeader } }
});
const { data: { user }, error } = await supabase.auth.getUser(); // ❌ No JWT parameter
```

**Fixed Code:**
```typescript
const supabase = createClient(supabaseUrl, supabaseAnonKey);
const jwt = authHeader.replace("Bearer ", "");
const { data: { user }, error } = await supabase.auth.getUser(jwt); // ✅ Pass JWT explicitly
```

### Files Modified

1. **Edge Function:** [matches-ingest/index.ts](../../../RefZoneiOS/Core/Platform/Supabase/functions/matches-ingest/index.ts)
   - Fixed: Pass JWT token to `getUser()` method
   - Deployed: Version 12 (2025-09-30)

2. **iOS Client:** [SupabaseMatchIngestService.swift](../../../RefZoneiOS/Core/Platform/Supabase/SupabaseMatchIngestService.swift)
   - Added: Explicit Authorization header in `FunctionInvokeOptions`
   - Added: Debug logging for user ID and token prefix

### Verification Results

✅ **401 Auth Issue: RESOLVED**

The edge function now successfully:
- Receives the Authorization header from iOS
- Extracts the user ID from the JWT
- Ingests matches into the database

From Supabase logs:
```
"matches-ingest: Successfully ingested match {
  matchId: "2f932df8-eda5-4b09-bf7c-e8cfecf8f7d0",
  userId: "22fe9306-52cd-493f-830b-916a3c271371"
}"
```
```
"POST | 200 | https://muwuzfbtmqwvwacqnofc.supabase.co/functions/v1/matches-ingest"
```

⚠️ **New Issue: iOS Decoding Error**

The iOS client is now getting a 200 response but fails to decode the response:
```
Supabase match push failed id=2F932DF8-EDA5-4B09-BF7C-E8CFECF8F7D0 error=The data couldn't be read because it isn't in the correct format.
```

This is likely a date format mismatch between what Postgres returns and what the iOS `JSONDecoder` expects.

---

## Summary for Next Developer

**Original Issue (RESOLVED):** Edge function was calling `supabase.auth.getUser()` without the JWT parameter, causing "Auth session missing" errors even though the JWT was validated by the platform.

**Fix Applied:** Pass the JWT explicitly to `getUser(jwt)` in the edge function code. Deployed as version 12.

**New Issue (IN PROGRESS):** iOS client receives 200 OK but fails to decode the response. The edge function returns `{match_id: uuid, updated_at: string}` but iOS decoder fails. Need to investigate date format compatibility between Postgres timestamp and Swift ISO8601 decoder.