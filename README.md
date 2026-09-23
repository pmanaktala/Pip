# Pip — Your Mood Companion

A small, Apple-native iOS app: a cute pet that visually reflects your mood, and — quietly — an extremely low-friction mood tracker.

- **One tap** to log a mood; the pet reacts with pose, expression and motion.
- **Three companions** (Pebble the penguin, Mochi the cat, Biscuit the dog) that notice you, answer the mood you log, and keep you company in it.
- **Widgets** everywhere: Home Screen, Lock Screen, StandBy, watch faces. A **Live Activity** that keeps you company after you log — no timers.
- **Apple Watch** companion with complications; moods logged on the wrist reach the phone in seconds (WatchConnectivity), with iCloud as the backup.
- **Apple Health** State of Mind sync, optional and write-only.
- **Private by design:** no accounts, no tracking, no analytics, no servers. Local-first with private CloudKit mirroring so history survives reinstalls.

Requires iOS 26. Built with the iOS 27 SDK; iOS 27-only niceties (the prominent tab, swipe actions outside lists, the tabs picker, cross-fade navigation, reduced-resource frame rates) are guarded with `#if compiler(>=6.4)` and `#available(iOS 27, *)`.
- **Apple Intelligence, on the device only:** the pet writes the History sentences from your entries with the system language model; nothing leaves the phone, and fixed phrases stand in wherever it is unavailable.

## Project

| Folder | What lives there |
| --- | --- |
| `Pip/` | App target: `App/` (entry, `AppState`), `Features/` (Pet, Mood, History, SitWithPet, Settings, Onboarding), `Health/`, `Resources/` |
| `PipCore/` | Shared with the widget extension: models, SwiftData store, services, design system, the pet renderer (`Pet/`), App Intents, Live Activity attributes |
| `PipWidgets/` | Widget extension: widgets, Live Activity UI |
| `PipWatch/` | Apple Watch app: the pet in its room, a two-tap mood log, sitting together. Moods, deletions and the chosen pet sync to the phone in seconds over WatchConnectivity (`DeviceSync`); the shared CloudKit store is the long-term backup |
| `PipWatchWidgets/` | Watch complications: circular and corner (the face), rectangular (face + how they feel), inline |
| `PipTests/` | Swift Testing unit tests (resolver, Health mapping, history, persistence, scheduler, icon render) |
| `AppStore/` | Metadata, review notes, release checklist |
| `scripts/` | `privacy-audit.sh` (run in CI and Xcode Cloud), `xcode-cloud-workflow.py` (creates the Xcode Cloud workflows via the App Store Connect API) |
| `ci_scripts/` | Xcode Cloud hooks: toolchain check, privacy audit + build-number stamping, TestFlight notes |
| `Docs/` | `Pets/Bible.md` (the pets: research, cast, motion, surfaces), `Design/Principles.md` (design and care rules), `XcodeCloud.md` (pipeline setup) |

### How the pet works

The rules are in [Docs/Pets/Bible.md](Docs/Pets/Bible.md). In short: a mood (or, when none is fresh, the pet's own day) is a **stance** — a resting pose, a prop, an idle character and a repertoire. `PetDirector` turns a scene (species, stance, recent events, a finger on the pet) and the clock into a `PetPose`: the stance, idle layers (breath, blinks, glances, sway, tail), one vignette at a time, event clips (arrival, the reaction to a log, boops, petting) and follow-through. It is a pure function of wall-clock time, so the phone, the watch and the widgets show the same pet. `PetRenderer` draws a pose in a 200 × 200 `Canvas` at three detail levels. `PetPresence` owns the live pet on the phone and the watch and passes pet events between them.

Review the art on the Mac with PetLab: `tools/PetLab/build.sh && /tmp/petlab poses|stances|reactions|vignettes|director|tokens <out.png> [species]`.

### Data

SwiftData in the App Group container, mirrored to the user's private CloudKit database (`iCloud.com.pmanaktala.Pip`). A tiny `PetSnapshot` in the App Group feeds widgets and Live Activities. `MoodLogger` is the single write path; side effects (Live Activity, Health) are registered by the app.

## Development

```bash
xcodebuild -project Pip.xcodeproj -scheme Pip -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

DEBUG launch environment for screenshots and previews:

- `PIP_SEED=1` — two weeks of demo moods
- `PIP_DEBUG=picker|history|pets|settings|sit|widgets|gallery|onboarding`
- `PIP_GALLERY_SPECIES=dog PIP_GALLERY_MOODS=happy,sad` — filter the pet gallery

Regenerate the app icon from the artwork:

```bash
TEST_RUNNER_PIP_ICON_OUTPUT=/tmp/icon.png xcodebuild test -project Pip.xcodeproj -scheme Pip -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PipTests/AppIconRenderTests
```

Then copy `/tmp/icon.png` to `Pip/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` and `/tmp/icon-layer.png` to `Pip/Resources/AppIcon.icon/Assets/Pebble.png`.

## Delivery

Pull requests are built and tested by GitHub Actions. Every push to `main` is archived by
Xcode Cloud and delivered to the internal TestFlight group; the build number is the Xcode Cloud
build number and the tester notes come from the commit log. Setup and troubleshooting live in
[Docs/XcodeCloud.md](Docs/XcodeCloud.md).

## Planning

Work is tracked in the [GitHub Project](https://github.com/users/pmanaktala/projects/4) and issues, grouped into milestones: Foundation, Core MVP, Apple Platform Integration, Polish, Release.

## Privacy

See [PRIVACY.md](PRIVACY.md). The privacy manifests live in `Pip/Resources/PrivacyInfo.xcprivacy` and `PipWidgets/Resources/PrivacyInfo.xcprivacy`.
