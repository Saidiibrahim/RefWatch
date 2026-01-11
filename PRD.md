# RefWatch Product Requirements Document

**Version:** 1.0
**Status:** Draft
**Last Updated:** January 2026

---

## Executive Summary

RefWatch is an AI-first referee development platform designed for football/soccer match officials at all levels. The product differentiates from existing referee apps (RefSix, RefLive, etc.) through intelligent AI-powered coaching, analysis, and Laws of the Game assistance.

**Primary Value Proposition:** AI-first referee development that helps officials improve through intelligent analysis, not just match logging.

**Current Status:** In development
**Target Launch Markets:** English-speaking (US, UK, Australia, Canada)
**Platform Strategy:** watchOS-first with iOS companion; Android phone companion planned for later

---

## Product Vision

### Mission
Empower football referees at all levels to develop their skills through intelligent match tracking, AI-powered analysis, and comprehensive fitness management.

### Strategic Positioning
| Dimension | Position |
|-----------|----------|
| **Primary Differentiator** | AI-first approach with full contextual intelligence |
| **Competition** | Displacing existing referee apps (RefSix, RefLive, etc.) |
| **Business Model** | Dual-track: B2C individual + B2B organizational (org tier post-v1) |
| **Monetization** | Freemium (AI cost-constrained in free tier) |

### Success Metrics (12-month horizon)
- **Primary:** User acquisition (referee count)
- **Secondary:** Engagement depth (matches logged per user)

---

## Target Users

### Primary Persona: Individual Referee
All referee levels from grassroots/youth to professional, with features that unlock complexity as users demonstrate need.

| Level | Characteristics | Feature Depth |
|-------|----------------|---------------|
| Grassroots/Youth | Volunteer refs, simplified matches | Basic timer, simple event logging |
| Competitive Amateur | Registered refs, league matches, career-focused | Full feature access, AI coaching |
| Semi-Pro/Professional | High-level refs, rigorous tracking | Advanced analytics, peer comparison |

### Future Persona: Assessor/Observer (Post-v1)
Referee coaches and assessors who:
- Conduct live observations at venues
- Review completed match logs post-match
- Access matches they've been assigned to (assignment-based access model)
- Provide feedback via structured rubrics, free-form text, and event-linked annotations

### Future Persona: Organization Buyer (Post-v1)
Three distinct stakeholders within referee associations/leagues:
1. **Assignment/Scheduling Managers** - Match coverage, referee availability
2. **Development Coordinators** - Referee progression, assessment outcomes
3. **Competition Administrators** - Match reports, incident documentation

---

## Platform Architecture

### Device Strategy

| Platform | Role | Status |
|----------|------|--------|
| **watchOS** | Primary match interface | Production-first |
| **iOS** | Companion app (library, analytics, AI) | Active development |
| **Android Phone** | Future companion | Planned |
| **Web** | Not planned | - |

### Standalone Requirements
The watchOS app operates **fully standalone** without iPhone proximity:
- All match data stored locally on watch
- No degradation during active matches
- Syncs to phone/cloud when connectivity available

### Sync Architecture
- **Tolerance:** Near-real-time required (for organizational use cases)
- **Source of Truth:** Wall-clock time (occurred_at) is primary; match time derived
- **Offline Handling:** Queue and retry with exponential backoff
- **Reliability Target:** Mission-critical; extensive performance testing to prevent failures

---

## Core Features (v1.0)

### 1. Match Timer & Event Tracking

**Platform:** watchOS (primary), iOS (mirror/history)

#### Timer Features
- Multiple selectable timer face styles
- Period tracking (configurable number of periods)
- Half-time countdown
- Extra time support
- Added time tracking
- Stoppage management

#### Event Capture
- **Interaction Model:** Detailed capture (full event details on watch)
- **Event Types:**
  - Goals (open play, penalty, own goal)
  - Cards (yellow, red, second yellow)
  - Substitutions (player in/out)
  - Kickoff and period transitions
  - Notes and stoppages

#### Penalty Shootouts
- Full ABBA sequence logic
- Automatic winner detection
- Sudden death continuation
- First-kicker designation

#### Error Handling
- Recent undo only (most recent event can be undone)
- Events lock after subsequent actions

#### Haptic Feedback
- Comprehensive coverage: event confirmations, timer milestones, critical alerts
- User-configurable intensity and scope

### 2. AI Assistant

**Platform:** iOS (primary)

#### Capabilities
| Use Case | Description |
|----------|-------------|
| **LOTG Reference** | Laws of the Game Q&A during match prep |
| **Post-Match Analysis** | Improvement suggestions based on match events |
| **Pattern Recognition** | Trends across multiple matches (e.g., card timing tendencies) |
| **Pre-Match Preparation** | Team/player insights for upcoming matches |

#### AI Context (Full Context Model)
The AI has access to:
- Current match events
- Referee's historical match patterns and tendencies
- Team/player data (anonymized)
- Referee wellness data from match day
- Laws of the Game corpus

#### Behavioral Guidelines
- **Proactivity:** User-controlled (can enable/disable proactive suggestions)
- **LOTG Disputes:** Conservative approach - advises referee to use their judgment on disputed calls
- **Cost Management:** AI cost is a concern; free tier access will be limited

#### Technical Implementation
- OpenAI GPT-4o-mini
- Usage tracking per user/day for cost control

### 3. Workout & Fitness Tracking

**Status:** Core feature (not secondary)

#### Workout Types
- Outdoor/Indoor Run
- Outdoor Walk
- Indoor Cycle
- Strength
- Mobility
- Referee Drill
- Custom

#### Features
- Workout presets with exercises
- Intensity zones (recovery, aerobic, tempo, threshold, anaerobic)
- Segment tracking (warmup, work, recovery, cooldown)
- Perceived exertion logging

#### HealthKit Integration
- **Direction:** Bidirectional sync
- Read: Import fitness data from Apple Health
- Write: Export RefWatch workout data to Apple Health

### 4. Wellness Tracking

**Purpose:** Multi-use feature serving four goals:
1. **Self-awareness** - Referee decides if fit for match
2. **Organizational visibility** - Assignors see referee readiness (future)
3. **Performance correlation** - AI links wellness to match outcomes
4. **Load management** - Prevent burnout and injury

#### Metrics Captured
- Sleep quality (1-10)
- Muscle soreness (1-10)
- Stress level (1-10)
- Mood (1-10)
- Free-form notes

### 5. Match Library

**Platform:** iOS

#### Entities
- **Teams** - Name, short name, division, colors, players, officials
- **Competitions** - Name, level
- **Venues** - Name, city, country, coordinates
- **Scheduled Matches** - Kickoff time, teams, competition, venue, status

#### Data Entry Methods
1. Manual entry in app
2. Import from league systems (Assignr, Arbiter, etc.) - planned
3. Organization push assignments - planned (post-v1)

### 6. Match Assessment & Reflection

#### Self-Assessment (Post-Match)
- Mood capture (calm, focused, stressed, fatigued)
- Performance rating (1-5)
- Structured reflection (overall, went well, to improve)

#### Pages/Notes
- Flexible notes system with TipTap rich text editor
- Page types: match report, training plan, fitness assessment, general note
- Tags, favorites, status (draft/submitted)
- Primary use: Personal archive (not league submission)

### 7. Trends & Analytics

#### Metrics Tracked
- Card patterns (timing, reasons, team distribution)
- Fitness metrics (distance, intensity, recovery)
- Game management (foul counts, advantage play, stoppage accuracy)
- Peer comparison (anonymous benchmarking)

---

## Data & Privacy

### Player Data Policy
**Approach:** Minimal/anonymous
- Capture jersey numbers primarily
- Player names are optional
- Designed to avoid GDPR/youth protection concerns

### Misconduct Templates
**Approach:** Configurable
- Organizations can define custom misconduct categories
- Base templates follow IFAB standard
- Supports league-specific card reasons

---

## Technical Requirements

### Minimum Platform Versions
- watchOS 11.2+
- iOS 17+ (assumed based on SwiftUI features)

### Backend Stack
- **Database:** Supabase (PostgreSQL)
- **Authentication:** Supabase Auth (Apple Sign-In, Google OAuth)
- **Local Persistence:** SwiftData
- **Device Sync:** WatchConnectivity framework
- **AI:** OpenAI API (gpt-4o-mini)

### Quality Requirements
- **Reliability:** Mission-critical during active matches
- **Testing:** Comprehensive performance tests to prevent mid-match failures
- **Accessibility:** Standard iOS/watchOS platform accessibility

---

## User Experience

### First-Use Experience
**Approach:** Flexible paths
- Users can start a match immediately (minimal friction)
- Or go through guided onboarding
- Or connect to organization first
- Multiple valid entry points based on user need

### Watch Match Flow
```
App Launch
├── Mode Selection (Match / Workout)
└── Match Mode
    ├── Home Screen (idle)
    ├── Match Setup
    │   ├── Team selection
    │   ├── Competition/venue
    │   └── Rules configuration
    ├── Kick Off
    │   ├── Period selection
    │   └── Ball possession
    ├── Active Timer
    │   ├── Event recording (goals, cards, subs)
    │   ├── Stoppage management
    │   └── Period transitions
    ├── Half Time
    ├── Extra Time (if enabled)
    ├── Penalties (if enabled)
    └── Full Time
        ├── Summary review
        └── Save confirmation
```

### iOS Tab Structure
1. **Matches** - Upcoming, history, quick-start
2. **Workout** - Activity dashboard, session tracking
3. **Trends** - Analytics and insights
4. **Assistant** - AI chat interface
5. **Settings** - Library management, preferences, auth

---

## Future Roadmap (Post-v1)

### Organizational Tier
- Assessor/observer workflows
- Assignment-based match access
- Feedback threads and annotations
- Coaching session management
- Custom misconduct templates per org
- Pricing model TBD

### Platform Expansion
- Android phone companion app (no Android watch planned)

### Advanced Features
- Video integration for assessor feedback
- League system integrations (Assignr, Arbiter, Refassign)
- Crew collaboration (multiple officials on same match)

---

## Competitive Landscape

### Primary Competitors
- RefSix
- RefLive
- Other referee timer/logging apps

### Differentiation Strategy
| Competitor Weakness | RefWatch Advantage |
|--------------------|-------------------|
| Phone-first interfaces | Native watchOS app for on-pitch use |
| Logging without insights | AI-powered analysis and coaching |
| Isolated match tracking | Connected development ecosystem (future) |
| Generic tools | Purpose-built for referee development |

---

## Open Questions

### Branding
- Product name (RefWatch) is working title - finalization needed
- Tagline and positioning to be developed

### Business Model
- Organizational tier pricing model undecided
- Free tier AI usage limits to be determined based on cost analysis

### Integrations
- Priority order for league system integrations
- API partnership requirements with Assignr/Arbiter/etc.

---

## Appendix: Database Schema Summary

### Core Tables
| Table | Purpose | Row Count |
|-------|---------|-----------|
| users | User accounts | 22 |
| matches | Completed match records | 32 |
| match_events | Timestamped match events | 263 |
| match_periods | Period tracking | 58 |
| scheduled_matches | Upcoming matches | 9 |
| teams | Team library | 8 |
| competitions | Competition library | 2 |
| venues | Venue library | 1 |

### Supporting Tables
- match_assessments, match_metrics, match_officials, match_reports
- workout_sessions, workout_presets, workout_events, workout_segments
- ai_threads, ai_messages, ai_attachments, ai_usage_daily
- wellness_check_ins, trend_snapshots
- feedback_threads, feedback_items, resource_shares
- coaching_sessions, pages

---

*This PRD is a living document and will be updated as product decisions evolve.*
