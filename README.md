# Pip — Your Mood Companion

A small, Apple-native iOS app: a cute pet that visually reflects your mood, and — quietly — an extremely low-friction mood tracker.

- **One tap** to log a mood; the pet reacts with pose, expression and motion.
- **Five pets** (cat, dog, capybara, penguin, red panda), each with a personality.
- **Widgets** everywhere: Home Screen, Lock Screen, StandBy. **Live Activities** for pet moments.
- **Apple Health** State of Mind sync, optional and write-only.
- **Private by design:** no accounts, no tracking, no analytics, no servers. Local-first with private CloudKit mirroring so history survives reinstalls.

Requires iOS 26. Built with the iOS 27 SDK; iOS 27-only niceties are guarded with availability checks.

## Project

| Folder | What lives there |
| --- | --- |
| `Pip/` | App target: `App/` (entry, `AppState`), `Features/` (Pet, Mood, History, SitWithPet, Settings, Onboarding), `Health/`, `Resources/` |
| `PipCore/` | Shared with the widget extension: models, SwiftData store, services, design system, the pet renderer (`Pet/`), App Intents, Live Activity attributes |
| `PipWidgets/` | Widget extension: widgets, Live Activity UI |
| `PipTests/` | Swift Testing unit tests (resolver, Health mapping, history, persistence, scheduler, icon render) |
| `AppStore/` | Metadata, review notes, release checklist |
| `scripts/` | `privacy-audit.sh` (run in CI) |

### How the pet works

`Mood × intensity × species × personality` → `PetStateResolver` → a `PetMoodState` containing a flat, numeric **`PetRig`** (ears, tail, eyes, brows, mouth, body) plus a motion profile. `PetView` draws the rig in a `Canvas`; because the rig is `Animatable`, mood changes interpolate as movement rather than crossfading images. `PetAnimator` layers deterministic idle motion (breathing, blinking, gaze, tail) on top, so widgets can render the exact same pet statically.

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

## Planning

Work is tracked in the [GitHub Project](https://github.com/users/pmanaktala/projects/4) and issues, grouped into milestones: Foundation, Core MVP, Apple Platform Integration, Polish, Release.

## Privacy

See [PRIVACY.md](PRIVACY.md). The privacy manifests live in `Pip/Resources/PrivacyInfo.xcprivacy` and `PipWidgets/Resources/PrivacyInfo.xcprivacy`.
