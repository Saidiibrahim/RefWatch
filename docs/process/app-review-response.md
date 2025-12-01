# App Review Response – HKWorkoutSession Use

Draft to paste into App Store Connect’s Resolution Center regarding Guideline 2.5.1:

Hi,

This app has two distinct modes on Apple Watch:
• Match Mode (non‑fitness) – used for time‑keeping, cards, and notes during a game. It does not start HKWorkoutSession. Instead, it relies on `WKExtendedRuntimeSession` purely to keep the match timer responsive when the screen is lowered.
• Workout Mode (fitness) – a full workout recorder for referees. It starts an HKWorkoutSession + HKLiveWorkoutBuilder** to capture and display real‑time fitness data.

Fitness metrics captured and shown in Workout Mode:
• Heart rate (live, avg, max)
• Active energy (kcal)
• Distance (m/km) with pace
• Elapsed time and lap/segment events
• Optional VO₂ Max when available

Data flows:
• Workout Mode writes workouts and metrics to HealthKit/Fitness.
• Match Mode never writes HealthKit data and only uses the extended runtime to keep the UI available.

Requested outcome:
• Please note that HKWorkoutSession is strictly confined to Workout Mode, which is core fitness functionality, while Match Mode uses Extended Runtime for non‑fitness tasks. We believe this aligns with Guideline 2.5.1 expectations for appropriate use of HKWorkoutSession and Extended Runtime.

Thank you for reconsidering the submission.

