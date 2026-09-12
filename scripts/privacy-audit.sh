#!/usr/bin/env bash
# Fails CI if anything that looks like tracking, analytics or a network backend sneaks in.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "::error::$1"; exit 1; }

for m in Pip/Resources/PrivacyInfo.xcprivacy PipWidgets/Resources/PrivacyInfo.xcprivacy; do
  [ -f "$m" ] || fail "Missing privacy manifest: $m"
  grep -A1 "NSPrivacyTracking</key>" "$m" | grep -q "<false/>" || fail "$m must declare NSPrivacyTracking = false"
  grep -A1 "NSPrivacyTrackingDomains</key>" "$m" | grep -q "<array/>" || fail "$m must declare no tracking domains"
  grep -A1 "NSPrivacyCollectedDataTypes</key>" "$m" | grep -q "<array/>" || fail "$m must declare no collected data types"
done

# No third-party packages at all.
if grep -q "XCRemoteSwiftPackageReference" Pip.xcodeproj/project.pbxproj; then
  fail "Remote Swift packages are not allowed without a privacy review"
fi
[ -f Podfile ] && fail "CocoaPods is not allowed"
[ -f Cartfile ] && fail "Carthage is not allowed"

# No analytics / attribution SDK identifiers in source.
if grep -rInE "Firebase|Crashlytics|Amplitude|Mixpanel|Segment\.|Adjust|AppsFlyer|Branch\.|Sentry|Bugsnag|Instabug|Facebook|FBSDK|GoogleAnalytics|ASIdentifierManager|AppTrackingTransparency|advertisingIdentifier" Pip PipCore PipWidgets --include=*.swift; then
  fail "Tracking / analytics SDK reference found"
fi

# No networking to non-Apple hosts in app code (CloudKit and HealthKit go through system frameworks).
if grep -rInE "URLSession|http://|https://" Pip PipCore PipWidgets --include=*.swift | grep -v "github.com/pmanaktala/Pip/blob/main/PRIVACY.md"; then
  fail "Direct networking found; Pip must not talk to servers"
fi

echo "Privacy audit passed."
