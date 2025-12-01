# Suggested App Store Description

Use this description to emphasize both Match Mode and Workout Mode features equally. This helps ensure reviewers understand the full scope of the app's functionality.

---

## App Name
**RefWatch - Referee Timer & Fitness**

(Alternative: "RefWatch: Timer & Workout Tracker")

---

## Subtitle (30 characters max)
**Match Timer & Workout Tracker**

(Alternative: "Referee Timer + Fitness")

---

## App Description

### Primary Description

**RefWatch is the ultimate companion for soccer referees, combining professional match timing with comprehensive fitness tracking.**

**⚽ MATCH MODE - Professional Referee Timer**

Keep perfect time during soccer matches with a dedicated referee timer designed for the pitch:

• Main match timer with automatic half tracking
• Injury/stoppage time tracking for accurate added time
• Period management (First Half, Second Half, Extra Time)
• Card tracking (Yellow and Red cards)
• Score tracking for match records
• Haptic feedback and visual alerts
• Background runtime keeps timer running when wrist is down
• Quick access controls for game management

Perfect for referees at all levels - from youth leagues to competitive matches.

**💪 WORKOUT MODE - Complete Fitness Tracking**

Train like a pro with full Apple Health integration and comprehensive workout tracking:

• Real-time heart rate monitoring
• Distance and pace tracking (GPS-enabled)
• Active energy expenditure (calories burned)
• Multiple workout types:
  - Outdoor Running
  - Indoor Running
  - Outdoor Walking
  - Indoor Cycling
  - Strength Training
  - Mobility & Flexibility
  - Referee Drill (HIIT)
  - Custom Workouts

• Live metrics display during workouts
• Automatic Apple Health sync
• Contributes to Activity Rings
• Workout history and performance trends
• Post-workout summaries with detailed statistics
• Heart rate zones and intensity tracking

Whether you're conditioning for match day or maintaining fitness between games, Workout Mode provides professional-grade fitness tracking powered by Apple's HealthKit.

**🎯 KEY FEATURES**

• Dual-mode design: Match timing and fitness tracking
• Apple Watch optimized interface
• Seamless Apple Health integration
• Background operation for both modes
• Intuitive controls designed for in-game use
• Haptic feedback for important events
• Offline functionality - no internet required
• Privacy-focused: Your data stays on your device

**👥 PERFECT FOR:**

• Soccer referees who want reliable match timing
• Referees training for fitness certifications
• Officials tracking their conditioning progress
• Anyone who wants both specialized timing and workout tracking
• Coaches managing match time and personal fitness

**⌚ APPLE HEALTH INTEGRATION**

RefWatch integrates seamlessly with Apple Health:
• Saves all workout data automatically
• Tracks heart rate, distance, and energy
• Contributes to Move, Exercise, and Stand goals
• View workout history in Health app
• Full HealthKit privacy compliance

**📱 REQUIREMENTS**

• Apple Watch Series 5 or later
• watchOS 11.2 or later
• HealthKit permissions for workout tracking (optional - only needed for Workout Mode)

---

Start your next match with confidence and track your fitness journey - all from your wrist with RefWatch.

---

## What's New (Version Update Notes)

**Template for next version:**

Version X.X.X
• Enhanced HealthKit integration for improved workout tracking
• Improved Match Mode timer accuracy
• Bug fixes and performance improvements

---

## Keywords (100 characters max, comma-separated)

referee,timer,soccer,football,workout,fitness,tracker,health,match,referee timer,workout tracker

---

## Promotional Text (170 characters, shown above description)

The complete app for soccer referees: Professional match timing + comprehensive fitness tracking with Apple Health integration. Two modes, one powerful app.

---

## App Store Screenshots Text Suggestions

### Screenshot 1: Main Menu
**Title:** Choose Your Mode
**Subtitle:** Match timing or fitness tracking

### Screenshot 2: Match Timer
**Title:** Professional Match Timer
**Subtitle:** Keep perfect time during games

### Screenshot 3: Workout Selection
**Title:** Multiple Workout Types
**Subtitle:** Running, cycling, strength & more

### Screenshot 4: Live Workout Metrics
**Title:** Real-Time Fitness Data
**Subtitle:** Heart rate, distance, pace, calories

### Screenshot 5: Apple Health Integration
**Title:** Syncs with Apple Health
**Subtitle:** Automatic workout saving & Activity Rings

---

## App Store Categories

**Primary Category:** Health & Fitness
**Secondary Category:** Sports

(Rationale: "Health & Fitness" emphasizes the Workout Mode features that use HealthKit)

---

## Privacy Labels for App Store Connect

### Data Collection:

**Health & Fitness:**
- Heart Rate (Workout Mode only)
- Workout (Workout Mode only)
- Other Fitness and Exercise Data (Workout Mode only)

**Usage:** Tracking and App Functionality
**Linked to User:** No
**Used for Tracking:** No

**Important Notes:**
- HealthKit permissions are only requested if user enters Workout Mode
- Match Mode does not require or collect any health data
- All data remains on device and in user's iCloud (via Apple Health)
- No third-party data sharing

---

## Support URL Suggestions

Consider creating a simple landing page or GitHub wiki with:
- Feature overview (Match Mode vs Workout Mode)
- Screenshots
- FAQ
- HealthKit permission explanation
- Contact information

Example URL structure:
- `https://yourdomain.com/refwatch`
- `https://github.com/yourusername/refwatch-support`

---

## Marketing URL Suggestions

A marketing page should highlight:
- Dual-mode functionality
- Target audience (referees who care about fitness)
- Key differentiators
- Testimonials (if available)
- Screenshots/videos

---

## App Preview Video Script (15-30 seconds)

**0:00-0:05:** "RefWatch - Built for referees"
- Show app icon and main menu

**0:05-0:12:** "Professional match timing with stoppage time tracking"
- Show Match Mode in action

**0:12-0:20:** "Complete fitness tracking with Apple Health"
- Show Workout Mode with live metrics

**0:20-0:25:** "Train, compete, and track your progress"
- Show workout summary and Apple Health integration

**0:25-0:30:** "RefWatch - Match Timer & Fitness Tracker"
- End card with app icon

---

## Tips for App Store Connect Setup

1. **Feature Workout Mode Prominently:**
   - Include at least 2-3 screenshots showing Workout Mode
   - Show Apple Health integration in screenshots
   - Mention "fitness tracking" in subtitle

2. **Category Selection:**
   - Primary: Health & Fitness (emphasizes HealthKit usage)
   - Secondary: Sports (covers referee use case)

3. **App Preview Video:**
   - Show BOTH modes in the video
   - Spend equal time on Match Mode and Workout Mode
   - Explicitly show fitness metrics and Apple Health

4. **In-App Purchases/Subscriptions:**
   - If you add premium features, ensure both modes have value
   - Don't lock fitness tracking behind paywall (helps justify HealthKit)

5. **Privacy Nutrition Labels:**
   - Be explicit that health data collection is optional
   - Explain that Match Mode doesn't need HealthKit
   - Clarify that Workout Mode requires HealthKit for functionality

---

## Review Notes for App Store Connect

When resubmitting, you can add "App Review Information" notes:

```
IMPORTANT FOR REVIEWERS:

RefWatch has TWO distinct modes:

1. MATCH MODE: Referee timer (uses WKExtendedRuntimeSession, NOT HealthKit)
2. WORKOUT MODE: Fitness tracker (uses HealthKit/HKWorkoutSession appropriately)

To test Workout Mode:
1. Launch app
2. Select "Workout Mode" from main menu
3. Choose any workout type (e.g., "Outdoor Run")
4. Start workout to see live heart rate, distance, pace
5. End workout to see summary and Apple Health integration

Workout Mode is a PRIMARY FEATURE with full fitness tracking capabilities.
HealthKit is used appropriately for legitimate fitness data collection.
```

---

## Implementation Checklist

When updating App Store Connect:

- [ ] Update app description to emphasize both modes equally
- [ ] Update subtitle to mention both timer and fitness
- [ ] Add keywords: "workout", "fitness", "tracker", "health"
- [ ] Primary category: Health & Fitness
- [ ] Include Workout Mode screenshots (minimum 3)
- [ ] Add Apple Health integration screenshot
- [ ] Create app preview video showing both modes (optional but recommended)
- [ ] Update promotional text to mention fitness tracking
- [ ] Add review notes explaining dual-mode architecture
- [ ] Update privacy labels for HealthKit data

---

This updated App Store presence will help future reviewers immediately understand that RefWatch is not just a timer app, but a comprehensive tool with legitimate fitness tracking features that appropriately use HealthKit.
