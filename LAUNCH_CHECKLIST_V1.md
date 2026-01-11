# RefWatch v1.0 Launch Checklist

**Target:** App Store release for individual referees
**Markets:** US, UK, Australia, Canada (English-speaking)
**Platforms:** watchOS + iOS

---

## 1. Core Feature Completion

### watchOS Match Timer
- [ ] Multiple timer face styles implemented and selectable
- [ ] Period tracking works for configurable period counts (2, 3, 4)
- [ ] Half-time countdown functional
- [ ] Extra time periods supported (when enabled)
- [ ] Added/stoppage time tracking accurate
- [ ] Timer continues running when app backgrounded
- [ ] Timer survives app restart mid-match

### watchOS Event Capture
- [ ] Goal recording (open play, penalty, own goal) with team selection
- [ ] Card recording (yellow, red, second yellow) with player number
- [ ] Substitution recording (player in/out)
- [ ] Kickoff and period transition events captured
- [ ] Notes/stoppage events functional
- [ ] Detailed capture flow works smoothly (full event info in ~3-4 taps)
- [ ] Recent undo functionality works correctly
- [ ] Events lock after subsequent actions

### Penalty Shootouts
- [ ] ABBA sequence logic implemented correctly
- [ ] Alternating sequence supported (for competitions using it)
- [ ] Automatic winner detection works
- [ ] Sudden death continuation logic correct
- [ ] First-kicker designation functional
- [ ] Score display updates in real-time

### Haptic Feedback
- [ ] Event confirmation haptics trigger correctly
- [ ] Timer milestone haptics (halftime, end of period, added time)
- [ ] Critical alert haptics functional
- [ ] Haptic intensity is configurable in settings
- [ ] Haptics don't fire excessively (no fatigue)

### iOS Companion - Matches Tab
- [ ] Match history displays all completed matches
- [ ] Match detail view shows full event log
- [ ] Scheduled matches display correctly
- [ ] Quick-start match option functional
- [ ] Match data syncs from watch reliably

### iOS Companion - Workout Tab
- [ ] All workout types available (run, walk, cycle, strength, mobility, drill, custom)
- [ ] Workout presets can be selected and started
- [ ] Intensity zone tracking works
- [ ] Segment tracking (warmup, work, recovery, cooldown) functional
- [ ] Perceived exertion can be logged post-workout
- [ ] HealthKit read integration working
- [ ] HealthKit write integration working

### iOS Companion - AI Assistant
- [ ] Chat interface functional
- [ ] LOTG reference queries return accurate responses
- [ ] Post-match analysis generates useful feedback
- [ ] Pattern recognition works across multiple matches
- [ ] Pre-match preparation insights available
- [ ] AI has access to full context (match + history + team + wellness + LOTG)
- [ ] User can enable/disable proactive AI suggestions
- [ ] Conservative approach on disputed LOTG calls implemented
- [ ] Usage tracking functional for cost control
- [ ] Free tier limits enforced

### iOS Companion - Trends Tab
- [ ] Card pattern analytics display
- [ ] Fitness metrics visualization
- [ ] Game management indicators shown
- [ ] Peer comparison (anonymous) functional
- [ ] Data updates after new matches sync

### iOS Companion - Settings Tab
- [ ] Match library CRUD (teams, competitions, venues)
- [ ] Scheduled match manual entry
- [ ] User preferences configurable
- [ ] Timer face selection syncs to watch
- [ ] Haptic preferences configurable
- [ ] AI proactivity toggle works

### Wellness Tracking
- [ ] Sleep quality input (1-10)
- [ ] Muscle soreness input (1-10)
- [ ] Stress level input (1-10)
- [ ] Mood input (1-10)
- [ ] Free-form notes field
- [ ] Wellness data feeds into AI context

### Match Assessment
- [ ] Post-match mood capture (calm, focused, stressed, fatigued)
- [ ] Performance rating (1-5) functional
- [ ] Structured reflection fields (overall, went well, to improve)
- [ ] Assessment linked to completed match

### Pages/Notes
- [ ] TipTap rich text editor functional
- [ ] All page types available (match report, training plan, fitness assessment, general note)
- [ ] Tags can be added/removed
- [ ] Favorites toggle works
- [ ] Draft/submitted status tracking

---

## 2. Sync & Data Reliability

### Watch-to-Phone Sync
- [ ] Completed matches sync from watch to phone
- [ ] Sync works via sendMessage when phone reachable
- [ ] Fallback to transferUserInfo (durable queue) works
- [ ] Library data syncs from phone to watch
- [ ] Sync status visible to user
- [ ] No data loss during sync failures

### Phone-to-Cloud Sync
- [ ] Matches sync to Supabase
- [ ] Library data (teams, competitions, venues) syncs
- [ ] Scheduled matches sync
- [ ] Workout data syncs
- [ ] Wellness data syncs
- [ ] Assessment data syncs
- [ ] Pages/notes sync
- [ ] Near-real-time sync achieved (within minutes)
- [ ] Offline queue with retry works
- [ ] Exponential backoff implemented
- [ ] Sync errors surface to user appropriately

### Standalone Watch Operation
- [ ] Watch stores all match data locally
- [ ] Full match can complete without phone nearby
- [ ] No feature degradation during standalone operation
- [ ] Data syncs when phone becomes available

### Data Integrity
- [ ] Wall-clock timestamps (occurred_at) recorded correctly
- [ ] Match time derived accurately from timer state
- [ ] No duplicate events on sync
- [ ] Idempotent sync operations

---

## 3. Authentication & Accounts

- [ ] Apple Sign-In functional
- [ ] Google OAuth functional
- [ ] Account creation flow smooth
- [ ] Sign-out works correctly
- [ ] Account data clears on sign-out
- [ ] Re-authentication after token expiry works
- [ ] Guest/anonymous usage possible (no account required for basic features)

---

## 4. Quality & Testing

### Performance
- [ ] Watch timer never skips or drifts during 120+ minute matches
- [ ] Event recording latency < 200ms on watch
- [ ] App launch time < 2s on watch
- [ ] App launch time < 3s on iOS
- [ ] No memory leaks during extended match sessions
- [ ] Battery usage acceptable (watch survives full match)

### Reliability
- [ ] App crash rate < 0.1%
- [ ] No crashes during active matches (mission-critical)
- [ ] Graceful degradation on network failures
- [ ] Data persists through app crashes
- [ ] App recovers state after force-quit

### Testing Coverage
- [ ] Unit tests for timer logic
- [ ] Unit tests for penalty shootout logic
- [ ] Unit tests for sync coordination
- [ ] UI tests for critical flows (match setup → timer → completion)
- [ ] Integration tests for watch-phone sync
- [ ] Performance tests for long-running matches
- [ ] Load tests for Supabase backend

### Device Testing
- [ ] Tested on Apple Watch Series 7+
- [ ] Tested on Apple Watch Ultra
- [ ] Tested on iPhone 12+
- [ ] Tested on various screen sizes
- [ ] Tested with low battery scenarios
- [ ] Tested with poor network connectivity

---

## 5. Privacy & Legal

### Privacy
- [ ] Privacy Policy written and hosted
- [ ] Privacy Policy linked in App Store listing
- [ ] Privacy Policy linked in app settings
- [ ] Player data is minimal/anonymous (jersey numbers only)
- [ ] No PII collected without consent
- [ ] Data deletion request process documented
- [ ] GDPR compliance verified (for UK users)

### Terms & Legal
- [ ] Terms of Service written and hosted
- [ ] Terms of Service linked in app
- [ ] OpenAI usage disclosed in terms
- [ ] Third-party licenses documented
- [ ] Apple Developer Program Agreement compliance

### App Store Compliance
- [ ] App Review Guidelines compliance verified
- [ ] HealthKit usage justified and explained
- [ ] No private API usage
- [ ] Content rating appropriate (4+)

---

## 6. App Store Preparation

### iOS App Store
- [ ] App name finalized
- [ ] Subtitle written (30 chars max)
- [ ] Description written (4000 chars max)
- [ ] Keywords optimized for referee/soccer/football terms
- [ ] Screenshots for all required device sizes
- [ ] App preview video (optional but recommended)
- [ ] Category selected (Sports)
- [ ] Age rating completed
- [ ] Privacy nutrition labels completed
- [ ] Support URL configured
- [ ] Marketing URL configured (if available)

### watchOS App Store
- [ ] Watch app screenshots
- [ ] Watch complications shown in screenshots
- [ ] Watch-specific features highlighted

### App Store Assets
- [ ] App icon (all sizes)
- [ ] Launch screen/splash screen
- [ ] Screenshots localized (if multi-language)

---

## 7. Onboarding & First-Use Experience

- [ ] New user can start match within 60 seconds (minimal friction path)
- [ ] Guided onboarding flow available for those who want it
- [ ] Key features discoverable without tutorial
- [ ] Watch app installable from iOS app
- [ ] Permissions requested at appropriate times (HealthKit, notifications)
- [ ] Permission rationale clear to users

---

## 8. Accessibility

- [ ] VoiceOver support on iOS
- [ ] VoiceOver support on watchOS
- [ ] Dynamic Type support
- [ ] Sufficient color contrast
- [ ] Touch targets appropriately sized (especially on watch)
- [ ] Timer readable in bright sunlight

---

## 9. Backend & Infrastructure

### Supabase
- [ ] Production database configured
- [ ] Row-Level Security (RLS) policies verified
- [ ] Database backups enabled
- [ ] Connection pooling configured
- [ ] Rate limiting in place

### OpenAI Integration
- [ ] Production API key configured
- [ ] Usage limits enforced per user/day
- [ ] Error handling for API failures
- [ ] Fallback behavior when AI unavailable
- [ ] Cost monitoring dashboard set up

### Monitoring & Observability
- [ ] Crash reporting enabled (Crashlytics/Sentry)
- [ ] Analytics tracking key events
- [ ] Backend error alerting configured
- [ ] Uptime monitoring for Supabase

---

## 10. Business & Monetization

### Freemium Model
- [ ] Free tier feature set defined
- [ ] AI usage limits for free tier determined
- [ ] Premium tier feature set defined (if launching with premium)
- [ ] In-app purchase configured (if applicable)
- [ ] Subscription management working (if applicable)

### Analytics & Metrics
- [ ] User acquisition tracking
- [ ] Retention metrics defined
- [ ] Engagement metrics (matches per user) tracked
- [ ] AI usage metrics tracked
- [ ] Conversion funnel defined (free → premium)

---

## 11. Marketing & Launch

### Pre-Launch
- [ ] Landing page live (if applicable)
- [ ] Social media accounts created
- [ ] Beta tester feedback incorporated
- [ ] Press kit prepared
- [ ] App Store Optimization (ASO) keywords finalized

### Launch Day
- [ ] App submitted to App Store review
- [ ] App approved
- [ ] Release date set
- [ ] Announcement posts scheduled
- [ ] Support channels ready (email, social)

### Post-Launch
- [ ] User feedback monitoring process
- [ ] Bug triage process defined
- [ ] Feature request tracking
- [ ] Review response strategy

---

## 12. Support & Operations

- [ ] Support email configured
- [ ] FAQ/Help documentation written
- [ ] In-app help accessible
- [ ] Bug reporting mechanism
- [ ] On-call process for critical issues
- [ ] Escalation path defined

---

## 13. Open Items to Resolve Before Launch

### Branding (from PRD Open Questions)
- [ ] Final product name decided
- [ ] Tagline finalized
- [ ] Logo/icon approved

### Business Model (from PRD Open Questions)
- [ ] Free tier AI usage limits set
- [ ] Decision on launching with premium tier or free-only

---

## Launch Go/No-Go Checklist

Before clicking "Release":

| Category | Status |
|----------|--------|
| All v1.0 features complete | ⬜ |
| Sync reliability verified | ⬜ |
| Performance tests passing | ⬜ |
| No critical/blocker bugs | ⬜ |
| Privacy policy live | ⬜ |
| App Store listing complete | ⬜ |
| Backend monitoring active | ⬜ |
| Support channels ready | ⬜ |
| Branding finalized | ⬜ |

---

## Post-Launch v1.1 Priorities

Items intentionally deferred from v1.0:
- [ ] League system import (Assignr, Arbiter)
- [ ] Organization push assignments
- [ ] Assessor/observer mode
- [ ] Video feedback integration
- [ ] Android companion app
- [ ] Multi-language support

---

*Last updated: January 2026*
