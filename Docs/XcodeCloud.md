# Xcode Cloud: main → TestFlight (internal)

Every push to `main` produces a signed TestFlight build for the internal group, with the build
number, notes for testers and privacy audit handled by the repository. Pull requests are
checked by GitHub Actions (`.github/workflows/ci.yml`) and, optionally, a second Xcode Cloud
workflow. Nothing in this pipeline needs a secret in the repo.

## What the repository provides

| Piece | Purpose |
| --- | --- |
| `Pip.xcodeproj/xcshareddata/xcschemes/Pip.xcscheme` | Shared scheme Xcode Cloud builds, tests (PipTests + PipUITests) and archives (Release). |
| `Pip.xcodeproj/xcshareddata/xcodecloud/manifest.json` | The Xcode Cloud product created from Xcode. |
| `ci_scripts/ci_post_clone.sh` | Logs the toolchain; fails fast if the SDK is older than iOS 26. |
| `ci_scripts/ci_pre_xcodebuild.sh` | Runs `scripts/privacy-audit.sh`; on archives stamps `CI_BUILD_NUMBER` into `CURRENT_PROJECT_VERSION` for both the app and the widget extension. |
| `ci_scripts/ci_post_xcodebuild.sh` | After a TestFlight archive writes `TestFlight/WhatToTest.en-US.txt` from recent commits, so every build carries notes. |
| `scripts/xcode-cloud-workflow.py` | Creates the workflows below through the App Store Connect API, so the setup is reproducible. |
| `Info.plist` → `ITSAppUsesNonExemptEncryption = false` | No export-compliance prompt per build. |
| `DEVELOPMENT_TEAM = 5JW755L832`, `CODE_SIGN_STYLE = Automatic` | Xcode Cloud manages certificates and profiles. |

Build numbers come from Xcode Cloud (`CI_BUILD_NUMBER`), so nobody edits them by hand and the
app and extension always match. `MARKETING_VERSION` (1.0) is the only version anyone bumps, for
a release.

## One-time setup in App Store Connect

1. **App record.** App Store Connect › Apps › + › iOS, bundle ID `com.pmanaktala.Pip`, name
   "Pip". Accept the Paid Apps / Developer agreements if prompted.
2. **Capabilities on the App IDs** (developer.apple.com › Identifiers):
   - `com.pmanaktala.Pip`: App Groups (`group.com.pmanaktala.Pip`), iCloud with CloudKit
     (`iCloud.com.pmanaktala.Pip`), HealthKit, Push Notifications.
   - `com.pmanaktala.Pip.PipWidgets`: App Groups.
   - `com.pmanaktala.Pip.watchkitapp` (the Watch app): App Groups, iCloud with CloudKit.
   - `com.pmanaktala.Pip.watchkitapp.PipWatchWidgets` (complications): App Groups.

   Automatic signing registers these on the first signed build from Xcode (Signing &
   Capabilities, each target); verify all four are present before the first cloud archive —
   a missing one is the most common "No profiles for …" failure.
3. **Internal tester group.** App Store Connect › the app › TestFlight › Internal Testing › +.
   Name it `Internal`, add only yourself, and turn on **Enable automatic distribution**. With
   that on, every build Xcode Cloud uploads reaches the group without a post-action.
4. **Connect the repository.** Xcode › Product › Xcode Cloud › Create Workflow (or App Store
   Connect › Xcode Cloud › Settings) and grant the Xcode Cloud GitHub App access to
   `pmanaktala/Pip`. This is what created `xcodecloud/manifest.json`.

## Workflows

### TestFlight (internal) — the one that matters

| Setting | Value |
| --- | --- |
| Start condition | Branch changes · `main` · auto-cancel builds |
| Environment | Latest **released** Xcode with the iOS 26+ SDK (Xcode 26 today; Xcode 27 once it ships), macOS latest. iOS 27-only APIs are guarded with `#if compiler(>=6.4)` + `#available(iOS 27, *)`, so the project builds with either SDK. (`compiler`, not `swift`: the project is in Swift language mode 5, and `#if swift(>=…)` tests the language mode, which silently disabled every guard until 21 Sep 2026.) |
| Action 1 | **Test** · scheme `Pip` · iPhone 17 Pro · latest iOS · required to pass |
| Action 2 | **Archive** · platform iOS · scheme `Pip` · Deployment preparation **TestFlight (Internal Testing Only)** |
| Post-action | **TestFlight Internal Testing** → group `Internal` (redundant if automatic distribution is on, harmless either way) |

Create it either by clicking through the table above, or with the script:

```bash
export ASC_KEY_ID=…  ASC_ISSUER_ID=…  ASC_PRIVATE_KEY=~/.private_keys/AuthKey_….p8
scripts/xcode-cloud-workflow.py --list
scripts/xcode-cloud-workflow.py --create
```

The key comes from App Store Connect › Users and Access › Integrations › App Store Connect API
(role App Manager). The script skips workflows that already exist and prints the payload with
`--dry-run`. It has been checked against the API contract but not run against this account yet;
if a field is rejected, the error names it and the table above is the ground truth.

### Pull request checks (optional)

Start condition: pull request changes → `main`. Actions: Build + Test on the simulator. GitHub
Actions already does this for free on a public repository, so this workflow is a convenience.

### Release (later)

Start condition: tag `v*`. Archive with deployment preparation **TestFlight and App Store**, no
automatic submission; submit from App Store Connect after the checklist in
`AppStore/RELEASE-CHECKLIST.md`.

## What a green build looks like

1. Clone → `ci_post_clone.sh` prints Xcode/SDK versions.
2. Test → `ci_pre_xcodebuild.sh` runs the privacy audit; 30 unit tests and 5 UI tests pass.
3. Archive → the pre-script stamps the build number; Xcode Cloud signs with the team's cloud
   certificate; `ci_post_xcodebuild.sh` writes the tester notes.
4. TestFlight processes the build (a few minutes); it appears on your device under the
   `Internal` group with the "Recent changes" notes.

## If something goes wrong

- **"No profiles for com.pmanaktala.Pip"** — a capability is missing on the App ID (step 2).
- **"CFBundleVersion of the extension must match"** — the pre-script did not run; check that
  `ci_scripts/*.sh` are executable (`chmod +x`) and live at the repository root.
- **Tests time out loading Accessibility** — the UI test runner on a cold simulator; Xcode Cloud
  retries once when "required to pass" is on. GitHub Actions boots the simulator first.
- **Widget renders blank in TestFlight** — App Group not entitled in the cloud-signed profile;
  re-check step 2 and re-run.
