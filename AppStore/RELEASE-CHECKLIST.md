# Release QA checklist

Run before every TestFlight / App Store build. Tick with the build number and date.

## Build & configuration

- [ ] `xcodebuild test` green locally and in CI (`.github/workflows/ci.yml`)
- [ ] `scripts/privacy-audit.sh` passes
- [ ] Deployment target iOS 26.0; built with the iOS 27 SDK
- [ ] Bump `MARKETING_VERSION` for a release (`CURRENT_PROJECT_VERSION` is stamped by Xcode Cloud from `CI_BUILD_NUMBER`; see `Docs/XcodeCloud.md`)
- [ ] Capabilities registered in the developer portal (Xcode › Signing & Capabilities does this on first signed build): App Group `group.com.pmanaktala.Pip`, iCloud container `iCloud.com.pmanaktala.Pip` (CloudKit), HealthKit, Push Notifications (CloudKit silent pushes)
- [ ] CloudKit schema deployed to **Production** in CloudKit Console (Development schema is created automatically by the first run; deploy it before App Store submission)
- [ ] Release entitlements: `aps-environment` becomes `production` in the archive (Xcode handles this automatically)
- [ ] Widget extension embedded; Live Activities enabled (`NSSupportsLiveActivities`)
- [ ] App icon: `AppIcon.icon` (layered) and 1024 PNG fallback both present; icon renders on Home Screen, Settings and App Library

## Persistence acceptance criteria

- [ ] Mood history survives app termination (force quit, relaunch)
- [ ] Mood history survives device restart
- [ ] App works fully in Airplane Mode; logging, history, pets and widgets all fine
- [ ] Offline entries sync to iCloud once connectivity returns (check second device or CloudKit Console)
- [ ] Delete app → reinstall on an iCloud-signed-in device → history, selected pet, name restored without a manual step
- [ ] Two devices, same iCloud: pet change on one appears on the other; exactly one `PetProfile` remains (de-duplication)
- [ ] No duplicate mood entries after sync or reinstall
- [ ] Widgets reflect restored state after reinstall (may take one timeline reload)
- [ ] Health sync on: reinstall does not create duplicate State of Mind samples (external UUID check)
- [ ] Delete All App Data removes local records, private CloudKit records (verify in CloudKit Console) and the App Group snapshot; app returns to onboarding; widgets show the empty pet
- [ ] Signed out of iCloud: app works, Settings shows iCloud "Unavailable" note, no nagging

## HealthKit

- [ ] Denying Health leaves the app fully functional
- [ ] Toggle reflects the real authorization state after changing it in the Health app
- [ ] Editing intensity/context within 20 s rewrites a single sample (no duplicates)
- [ ] Turning sync off keeps existing Health samples; copy in Settings says so

## Widgets & Live Activities

- [ ] Small, medium, large widgets render in light, dark and tinted modes
- [ ] Medium widget quick-mood buttons log without opening the app and refresh the timeline
- [ ] Lock Screen circular, rectangular and inline widgets legible
- [ ] StandBy: small widget shows the pet on the floor without a container background
- [ ] Mood-change Live Activity appears after logging and dismisses itself (12–30 min)
- [ ] Live Activity tap opens the app (`pip://home`) or Sit With Pet (`pip://sit`)
- [ ] Never more than one Live Activity at a time; rapid logging replaces rather than stacks
- [ ] Live Activity and notification preferences respected

## Accessibility

- [ ] VoiceOver: pet state announced ("Mochi looks calm"), every button labelled, mood tiles have hints
- [ ] Dynamic Type through AX5: mood grid reflows to two columns, no clipped text
- [ ] Reduce Motion: no idle animation, mood changes still understandable
- [ ] Increase Contrast / Smart Invert sanity check
- [ ] Colour is never the only mood cue (pose + expression always change)

## Devices & modes

- [ ] iPhone 17 Pro Max, iPhone 17, iPhone 17e / SE-class width
- [ ] iOS 26.0 simulator (fallbacks: segmented picker, grouped toolbar, default transitions)
- [ ] iOS 27 (tabs picker, toolbar priority, cross-fade)
- [ ] Light and dark on every screen; onboarding, picker, history, pets, settings, sit
- [ ] Silent switch respected by ambient sound; sound off by default

## Privacy & compliance

- [ ] No network calls (Instruments › Network shows only CloudKit/HealthKit system traffic)
- [ ] Privacy manifests present in app and extension
- [ ] App Privacy answers in App Store Connect match `AppStore/METADATA.md`
- [ ] Privacy policy URL live
- [ ] `ITSAppUsesNonExemptEncryption` = false

## Submission

- [ ] Screenshots captured (see `AppStore/METADATA.md`)
- [ ] TestFlight build installed on a physical device; onboarding → log → widget → Live Activity → Health verified end to end
- [ ] Review notes pasted into App Store Connect
