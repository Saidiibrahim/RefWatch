# App Store Connect Submission Instructions

Complete step-by-step guide for submitting your appeal to Apple.

---

## 📋 Pre-Submission Checklist

Before you begin, ensure you have:

- [ ] **Appeal letter** - Customized with your name and app version
- [ ] **Screenshots** - Minimum 5-7 images showing Workout Mode
- [ ] **Apple Health screenshots** - At least 1-2 showing integration
- [ ] **Screenshots annotated** (optional but helpful)
- [ ] **Video demo** (optional)
- [ ] **Screenshots organized** in a folder for easy access

---

## 🚀 Step-by-Step Submission Process

### Step 1: Access App Store Connect

1. Go to [https://appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Navigate to **"My Apps"**
4. Click on **"RefWatch"** (or your app name)

### Step 2: Locate Resolution Center

1. In your app's page, look for the top navigation tabs
2. Click on **"App Store"** tab
3. Find the version that was rejected (should show "Rejected" status)
4. Look for **"Resolution Center"** option or **"Appeal"** button

**Alternative path:**
- From the main App Store Connect dashboard
- Click **"Resolution Center"** in the top-right toolbar
- Find your rejected app submission

### Step 3: Initiate Appeal

1. Click **"Appeal Decision"** or **"Submit Appeal"** button
2. You should see the rejection message:
   ```
   Guideline 2.5.1 - Performance - Software Requirements

   The app uses HKWorkoutSession, but the app does not appear to
   include any primary features that require fitness data.
   ```

### Step 4: Write Your Appeal Message

1. In the text box provided, **copy and paste** the appeal letter from `appeal-response.md`
2. **Before pasting**, customize these fields:
   - Replace `[VERSION]` with your actual version number (e.g., "1.2.0")
   - Replace `[Your Name]` with your name
3. **Review the letter** to ensure it makes sense for your situation
4. **Optional additions:**
   - Add your Apple Developer contact email
   - Add App Store URL once published (for reference)

### Step 5: Attach Supporting Materials

1. Look for **"Attachments"** or **"Add Files"** section
2. Click **"Choose Files"** or **"Add Attachment"**
3. **Upload screenshots** in this recommended order:
   - `01-main-menu-mode-selection.png`
   - `02-workout-type-selection.png`
   - `03-live-workout-heart-rate.png`
   - `04-live-workout-all-metrics.png`
   - `05-workout-summary.png`
   - `06-workout-history-list.png`
   - `08-apple-health-refwatch-workout.png`
   - `09-apple-health-activity-rings.png`

4. **File upload limits:**
   - Maximum file size: Usually 25MB per file
   - Accepted formats: PNG, JPEG, PDF, MOV, MP4
   - Maximum attachments: Typically 5-10 files

5. **If uploading a video:**
   - Keep it under 2-3 minutes
   - Show clear demonstration of Workout Mode
   - Ensure audio is clear (if narrating)

### Step 6: Add Review Notes (Optional)

Some appeal forms have a "Notes for Review" or "Additional Information" section.

**Suggested text:**
```
TESTING INSTRUCTIONS FOR REVIEWERS:

To test the Workout Mode features that use HealthKit:

1. Launch RefWatch on Apple Watch
2. From main menu, tap "Workout Mode"
3. Select any workout type (e.g., "Outdoor Run")
4. Grant HealthKit permissions if prompted
5. Start the workout
6. Observe live metrics: Heart rate, Distance, Pace, Calories
7. Let workout run for 1-2 minutes
8. End workout and view summary with fitness statistics
9. Open Apple Health app to verify workout was saved

Match Mode uses WKExtendedRuntimeSession and does NOT access HealthKit.
Workout Mode uses HKWorkoutSession for legitimate fitness tracking.

Both modes are primary features of the app.
```

### Step 7: Review Before Submitting

**Double-check:**
- [ ] Appeal letter is complete and customized
- [ ] All required screenshots are attached
- [ ] File names are professional (not "Screenshot 1.png")
- [ ] Screenshots are clear and readable
- [ ] Apple Health integration is demonstrated
- [ ] Testing instructions are included (if field exists)
- [ ] Your contact information is correct

### Step 8: Submit Appeal

1. Click **"Submit"** or **"Send Appeal"** button
2. You should see a confirmation message
3. **Take a screenshot** of the confirmation for your records
4. Note the submission date and time

---

## ⏰ What Happens Next?

### Timeline:
- **Acknowledgment:** Usually within 24 hours (automated email)
- **Review time:** 2-5 business days (sometimes faster)
- **Response:** Email notification when decision is made

### Possible Outcomes:

#### ✅ Outcome 1: Appeal Approved
- You'll receive an email: "Your appeal has been approved"
- App will move to "Ready for Sale" or "Pending Developer Release"
- You can release the app immediately or schedule release

**Next steps if approved:**
1. Celebrate! 🎉
2. Monitor user feedback
3. Consider updating App Store description to emphasize Workout Mode
4. Plan future updates

#### ⚠️ Outcome 2: Appeal Denied with Same Reason
- Email will reiterate Guideline 2.5.1
- May include additional explanation

**Next steps if denied:**
See "Plan B: If Appeal is Rejected" section below

#### 📝 Outcome 3: Additional Information Requested
- Reviewer may ask for more details or clarification
- May request additional screenshots or demo video

**Next steps:**
1. Respond promptly (within 24-48 hours)
2. Provide exactly what they're asking for
3. Be professional and factual
4. Don't be defensive

---

## 🔄 Plan B: If Appeal is Rejected

If your initial appeal is denied, you have several options:

### Option 1: Request Phone Call with App Review
1. In Resolution Center, look for "Request a Call" option
2. Explain you'd like to discuss the dual-mode architecture
3. Prepare talking points:
   - App has two distinct modes
   - Workout Mode is a complete fitness tracking feature
   - Match Mode uses Extended Runtime (not HealthKit)
   - Request specific feedback on what's missing

### Option 2: Submit a Second Appeal with Enhanced Evidence
1. Add more screenshots showing Workout Mode prominence
2. Include video demonstration (if you didn't before)
3. Add user testimonials about Workout Mode (if available)
4. Expand explanation of fitness tracking features
5. Reference specific App Store guidelines:
   - Guideline 2.5.13 (HealthKit)
   - Guideline 5.1.1 (Data Collection and Storage)

### Option 3: Enhance Workout Mode Visibility
Before resubmitting:
1. **Update App Store metadata:**
   - Change subtitle to emphasize fitness tracking
   - Add "Workout Tracker" to app name
   - Update description to list Workout Mode first
   - Change primary category to "Health & Fitness"

2. **Update in-app onboarding:**
   - Add tutorial explaining both modes
   - Show Workout Mode features during first launch
   - Add "What's New" screen highlighting fitness features

3. **Resubmit with explanation:**
   - Note the changes made
   - Emphasize enhanced visibility of fitness features
   - Resubmit appeal with updated metadata

### Option 4: Code Changes (Last Resort)
If all appeals fail, consider these code modifications:

**Option 4A: Add Workout Mode Prominence**
- Make Workout Mode the default/first tab
- Add onboarding tutorial showcasing fitness features
- Add notification reminders to use Workout Mode
- Add widget showing recent workouts

**Option 4B: Temporarily Remove HealthKit (Not Recommended)**
- Create a version without Workout Mode
- Submit for approval
- Add Workout Mode back in next update
- **Risk:** May face same rejection in future update

**Option 4C: Make Workout Mode More Feature-Rich**
- Add workout planning features
- Add training programs
- Add fitness goals and achievements
- Add social features for sharing workouts
- This makes Workout Mode even more clearly a "primary feature"

---

## 📞 Contacting App Review Directly

### When to Contact:
- After 7+ days with no response
- If you receive unclear rejection reasoning
- If you believe there's a technical misunderstanding

### How to Contact:

**1. Resolution Center:**
- Best for formal appeals and documentation

**2. Phone Call Request:**
- Available in Resolution Center
- Usually scheduled within 24-48 hours
- Speak directly with App Review team member

**3. Apple Developer Forums:**
- Post in "App Store Review" section
- Apple employees sometimes respond
- Good for getting community feedback

**4. Developer Support:**
- https://developer.apple.com/contact/
- Choose "App Review"
- Good for technical questions

### What to Prepare for Phone Call:
- Clear explanation of Match Mode vs Workout Mode
- List of specific fitness metrics tracked
- Screenshots ready to share (via email if requested)
- Calm, professional demeanor
- Specific questions about what Apple needs

---

## 📊 Tracking Your Appeal

### Create a tracking document:

```
Appeal Submission Tracker
========================

Submission Date: [DATE]
Appeal Method: Resolution Center
Version Submitted: [VERSION]

Supporting Materials:
- [x] Appeal letter
- [x] 8 screenshots
- [ ] Video demonstration

Status Updates:
- [DATE] - Submitted appeal
- [DATE] - Received acknowledgment email
- [DATE] - [Update status as received]

Reviewer Questions:
- None yet

Notes:
- [Add any relevant notes]
```

---

## ✉️ Email Response Template (If Asked for More Info)

If Apple requests additional information:

```
Subject: Re: RefWatch - Additional Information for Appeal

Dear App Review Team,

Thank you for reviewing my appeal. I'm happy to provide additional
information about RefWatch's fitness tracking features.

[Answer their specific questions here]

To summarize RefWatch's HealthKit usage:
- Workout Mode tracks heart rate, distance, pace, and energy
- All fitness data is displayed in real-time during workouts
- Workouts are saved to Apple Health with complete statistics
- Users can view workout history within the app
- Match Mode does NOT use HealthKit (uses WKExtendedRuntimeSession)

I've attached [number] additional screenshots showing [what they show].

Please let me know if you need any other information.

Best regards,
[Your Name]
```

---

## 🎯 Success Tips

### Do's:
✅ Be professional and respectful in all communications
✅ Provide clear, concrete evidence (screenshots, video)
✅ Explain the dual-mode architecture clearly
✅ Emphasize that Workout Mode is a primary feature
✅ Reference specific Apple guidelines
✅ Respond promptly to requests (within 24-48 hours)
✅ Keep records of all communications

### Don'ts:
❌ Don't be defensive or argumentative
❌ Don't blame the reviewers
❌ Don't submit multiple appeals simultaneously
❌ Don't make threats or ultimatums
❌ Don't spam with repeated appeals
❌ Don't provide false information
❌ Don't hide or downplay HealthKit usage

---

## 📈 After Approval

Once your app is approved:

1. **Update App Store listing:**
   - Add Workout Mode screenshots to carousel
   - Update description to highlight both modes
   - Add keywords: workout, fitness, health

2. **Monitor reviews:**
   - Watch for user feedback about Workout Mode
   - Respond to questions about fitness features
   - Use feedback for future improvements

3. **Plan future updates:**
   - Continue enhancing both modes equally
   - Add more workout types if needed
   - Improve fitness metrics display
   - Add training plans or programs

4. **Document this experience:**
   - Keep appeal materials for future reference
   - May help if you face similar issue with update
   - Share learnings with other developers (anonymously)

---

## 🆘 Emergency Contacts

If you're completely stuck:

- **Apple Developer Support:** https://developer.apple.com/contact/
- **Developer Forums:** https://developer.apple.com/forums/
- **Twitter:** @AppleSupport or @AppStore
- **Legal (if needed):** Developer Program License Agreement Section [relevant section]

---

## 📱 Quick Reference Checklist

**Before Submitting:**
- [ ] Customized appeal letter
- [ ] 5-7 screenshots attached
- [ ] Apple Health integration shown
- [ ] Testing instructions included
- [ ] Contact info correct

**After Submitting:**
- [ ] Confirmation received
- [ ] Screenshot of submission saved
- [ ] Calendar reminder set for 5 business days
- [ ] Tracking document created

**While Waiting:**
- [ ] Prepare for potential phone call
- [ ] Have app ready to demo live
- [ ] Review App Store description for improvements
- [ ] Consider video demo if not already created

---

## Estimated Timeline

- **Screenshot gathering:** 30-60 minutes
- **Appeal writing:** 15-30 minutes (if using template)
- **Submission process:** 10-15 minutes
- **Apple response:** 2-5 business days
- **Total time to resolution:** 3-7 days typically

---

## Final Checklist Before Clicking Submit

- [ ] App version number is correct in letter
- [ ] Your name is included in signature
- [ ] All screenshots are attached and visible
- [ ] Screenshots clearly show fitness tracking
- [ ] Apple Health integration is demonstrated
- [ ] Letter explains Match Mode uses Extended Runtime
- [ ] Letter explains Workout Mode is primary feature
- [ ] Testing instructions are clear
- [ ] You've saved a copy of everything submitted
- [ ] You're ready to respond quickly if asked for more info

---

**Ready to submit?**

Take a deep breath, review one more time, and click that Submit button!

Good luck! 🍀

Your app is correctly implemented, and you have a strong case for approval.
