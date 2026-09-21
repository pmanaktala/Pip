#!/bin/zsh
# Xcode Cloud: runs once after the repository is cloned, before any build action.
#
# Pip has no package dependencies, so there is nothing to install. This step records the
# toolchain the build is about to use and fails fast if the SDK is older than the project
# needs (iOS 27-only APIs are guarded at compile time, but the deployment target is iOS 26).
set -euo pipefail

echo "== Xcode Cloud environment"
echo "Workflow:      ${CI_WORKFLOW:-?}"
echo "Action:        ${CI_XCODEBUILD_ACTION:-?}"
echo "Branch/tag:    ${CI_BRANCH:-${CI_TAG:-?}}"
echo "Build number:  ${CI_BUILD_NUMBER:-?}"
echo "Commit:        ${CI_COMMIT:-?}"
xcodebuild -version

SDK_VERSION=$(xcrun --sdk iphoneos --show-sdk-version)
echo "iOS SDK:       $SDK_VERSION"
if [[ "${SDK_VERSION%%.*}" -lt 26 ]]; then
  echo "error: Pip needs the iOS 26 SDK or newer; this environment has $SDK_VERSION. Pick a newer Xcode in the workflow's Environment settings." >&2
  exit 1
fi
