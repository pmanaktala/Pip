# App Store metadata

## Names

- **App name:** Pip — Your Mood Companion
- **Display name (Home Screen):** Pip
- **Bundle ID:** com.pmanaktala.Pip
- **Primary category:** Health & Fitness · **Secondary:** Lifestyle
- **Age rating:** 4+

## Subtitle (30 chars)

`A little pet that feels with you`

## Promotional text (170 chars)

Log how you feel in one tap and watch your pet feel it too — on your Home Screen, your Lock Screen and in Apple Health. Private by design. No accounts, no tracking.

## Description

Meet Pip: a small, expressive pet that reflects how you feel.

Tell Pip you're calm, stressed, excited or tired, and your pet reacts — ears, tail, posture, the works. That's the whole idea. No forms, no streaks, no lectures. Just a tiny companion who's glad you stopped by.

**One tap, then you're done**
Open the app or a widget, tap a face, and your mood is logged. Add how strongly you feel it, why, or a short note — only if you want to.

**A pet that lives on your phone**
Home Screen and Lock Screen widgets keep your pet close. StandBy turns it into a little desk companion. After you log a mood, a short Live Activity shows your pet reacting — then quietly goes away.

**Five pets, five personalities**
Mochi the dramatic cat. Biscuit the optimistic dog. Juniper the unbothered capybara. Pebble the chaotic penguin. Rusty the sleepy red panda. Same mood, slightly different reaction.

**A history you'll actually look at**
Your month is a calendar of tiny pet faces. Your day is a three-scene recap: "Mochi had a chaotic Tuesday." No charts pretending to diagnose you.

**Sit together**
When you need a minute, open Sit With Pet: your pet breathes, the room is quiet, nothing needs finishing. Stay two seconds or ten minutes.

**Apple Health, optionally**
Turn on Health sync and each mood becomes a State of Mind entry in Apple Health — written, never read.

**Private by design**
No accounts. No tracking. No analytics. No ads. No servers. Your history stays on your device and in your private iCloud, where only you can see it, and it comes back if you reinstall or change phones.

Pip is not therapy and doesn't pretend to be. It's a small, kind way to notice how you're doing.

## Keywords (100 chars)

`mood,tracker,pet,journal,feelings,state of mind,widget,companion,wellbeing,cute,diary,emotion`

## What's new (1.0)

First release. Five pets, eight moods, widgets everywhere, Live Activities, Apple Health sync, and a promise: no tracking, ever.

## Support & privacy URLs

- Support: https://github.com/pmanaktala/Pip/issues
- Privacy policy: https://github.com/pmanaktala/Pip/blob/main/PRIVACY.md

## App Privacy (nutrition label answers)

- **Do you or your third-party partners collect data from this app?** → **No, we do not collect data from this app.**
  - Mood entries, notes and pet data are stored on device and in the user's private CloudKit database; the developer has no access. Apple's guidance treats data that never leaves the user's device/iCloud private database and is not accessible to the developer as *not collected*.
  - No analytics, advertising, crash reporting or tracking SDKs.
- **Tracking:** No. App Tracking Transparency is not used because no tracking occurs.
- **Privacy manifests:** `Pip/Resources/PrivacyInfo.xcprivacy` and `PipWidgets/Resources/PrivacyInfo.xcprivacy` declare `NSPrivacyTracking = false`, no tracking domains, no collected data types, and required-reason APIs (UserDefaults CA92.1 / 1C8F.1 for App Group sharing, file timestamps C617.1).

## App Review notes

- **HealthKit:** Pip requests *write* access to State of Mind only, and only when the user turns on "Save moods to Apple Health" (onboarding step or Settings). No read permission is requested. The purpose string explains exactly what is written. The app is fully functional without Health access. To test: Settings › Apple Health › toggle on › log a mood › see the entry in Health › Mental Wellbeing › State of Mind (writes happen within ~20 s to allow the optional refinement step).
- **Live Activities:** started locally after logging a mood and for occasional "pet moments"; each ends itself after 12–30 minutes. No push notifications are used.
- **Notifications:** optional, off by default, at most one per day, never a reminder to log.
- **iCloud:** private CloudKit database via SwiftData; no developer-accessible data. The app works without iCloud.
- **Accounts:** none. There is no login.
- **Demo:** nothing to configure — open the app, pick a pet, tap a mood.

## Screenshots (6.9" and 6.5")

1. Home — Mochi calm on the warm scene, glass mood button ("Your mood, as a pet")
2. Mood picker sheet with the pet reacting above it ("One tap. Done.")
3. Pets — Biscuit card ("Five pets, five personalities")
4. History month grid of pet faces ("A history you'll actually look at")
5. Widgets on the Home Screen + Lock Screen ("Lives on your phone")
6. Live Activity banner ("Moments, not nags")
7. Sit With Pet, dark mode ("Sit together")
8. Settings › Privacy ("No tracking. Ever.")

Capture with the DEBUG launch environment (`PIP_SEED=1`, `PIP_DEBUG=picker|history|pets|sit|settings|widgets`) on an iOS 27 simulator, light and dark.
