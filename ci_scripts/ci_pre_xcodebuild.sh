#!/bin/zsh
# Xcode Cloud: runs before every xcodebuild action (build, test, analyze, archive).
#
# 1. Privacy audit — the build fails if tracking SDKs, networking or unexpected URLs appear.
# 2. Build number — for archives, stamp CI_BUILD_NUMBER into every target so the app and the
#    widget extension carry the same CFBundleVersion (App Store Connect rejects a mismatch) and
#    every TestFlight build is unique without anyone editing the project.
set -euo pipefail

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

echo "== Privacy audit"
scripts/privacy-audit.sh

if [[ "${CI_XCODEBUILD_ACTION:-}" == "archive" && -n "${CI_BUILD_NUMBER:-}" ]]; then
  echo "== Stamping build number $CI_BUILD_NUMBER"
  # CURRENT_PROJECT_VERSION lives at the project level and is inherited by both targets;
  # rewrite every occurrence so a future per-target override can't drift.
  sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" Pip.xcodeproj/project.pbxproj
  grep -c "CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};" Pip.xcodeproj/project.pbxproj | xargs -I{} echo "{} build settings updated"
fi
