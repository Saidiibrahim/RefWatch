# Supabase Email + Google Auth Implementation Plan

## Goals
- Support Supabase-native email/password sign-up & sign-in.
- Provide first-class Google OAuth sign-in inside the iOS app.
- Preserve existing Apple sign-in support and session-aware sync services.

## Backend Configuration Checklist
1. **Auth Settings**
   - Enable *Email Confirmations* if required by product policy.
   - Ensure `Allow email signups` and `Allow email sign-ins` are toggled on.
   - Configure a production redirect URL for native apps (e.g. `refwatch://auth-callback`).
2. **Email Templates**
   - Update confirmation + reset templates with RefZone branding.
   - Verify the confirmation email contains actionable CTA.
3. **Google Provider**
   - Create OAuth credentials in Google Cloud console (iOS application type).
   - Authorized redirect URIs must include Supabase callback (`https://<project>.supabase.co/auth/v1/callback`) and the native custom scheme `refwatch://auth-callback`.
   - Paste the Google client ID/secret into Supabase → Authentication → Providers → Google and toggle **Enabled**.
4. **Keys & Secrets**
   - Rotate publishable/anon key if migrating from Clerk to avoid stale builds.
   - Update the corresponding values in `Secrets.xcconfig` and CI secrets.

## iOS App Tasks
1. **Configuration**
   - Confirm `GIDClientID` placeholder resolves via `Secrets.xcconfig`.
   - Ensure `CFBundleURLTypes` contains both `refwatch` (Supabase redirect) and Google reversed client ID.
   - Add `LSApplicationQueriesSchemes` entries if Google requires (e.g. `com.googleusercontent.apps.*`).
2. **Supabase Client**
   - Keep `SupabaseClientProvider` singleton and ensure function auth refresh after session changes.
3. **Email Auth Flow**
   - Validate credentials via `SupabaseCredentialValidator` before hitting network.
   - Use `client.auth.signInWithPassword(email:password:)` / `signUp` and consume the returned `AuthResponse`.
   - When `AuthResponse.session == nil`, surface `SupabaseAuthError.emailConfirmationRequired` and keep state signed out.
   - Clear password field and show alert instructing confirmation.
4. **Google Sign-In**
   - Use `GIDSignIn` async bridge with nonce hashing, supply `GIDConfiguration(clientID:)` from plist when missing.
   - Pass hashed nonce to Google, original nonce to Supabase `signInWithIdToken`.
   - Handle cancellations cleanly and reset loading state.
5. **Session Lifecycle**
   - Observe `client.auth.authStateChanges` and update `SupabaseAuthController.state`.
   - Refresh Supabase Functions auth headers whenever session toggles.
   - Persist session via Supabase SDK (Keychain) and call `restoreSessionIfAvailable()` on app launch.

## UX & Messaging
- Display inline alerts for validation issues and Supabase errors.
- On confirmation-required sign-up, show a positive alert and do not wipe email field.
- Provide "Forgot password" entry point (follow-up enhancement).

## QA Matrix
- Email sign-up (new user, existing email, invalid email, weak password).
- Email sign-in (valid, wrong password, unconfirmed account).
- Google sign-in (first install, returning user, cancellation).
- Apple sign-in regression pass.
- Offline attempts should show network messaging.

## Follow-ups
- Add password reset flow (Supabase magic link).
- Build out watchOS companion awareness of session state.
- Telemetry: emit auth events to analytics once instrumentation is available.
