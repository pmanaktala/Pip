#!/bin/zsh
# Xcode Cloud: runs after every xcodebuild action.
#
# After a TestFlight-signed archive, write the "What to Test" notes from the commits since the
# previous build so every TestFlight build explains itself. Xcode Cloud picks the file up from
# a TestFlight folder next to ci_scripts (see "Including notes for testers with a Xcode Cloud
# workflow" in Apple's documentation).
set -euo pipefail

if [[ "${CI_XCODEBUILD_ACTION:-}" != "archive" || -z "${CI_APP_STORE_SIGNED_APP_PATH:-}" ]]; then
  exit 0
fi

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"
NOTES_DIR="$REPO/TestFlight"
mkdir -p "$NOTES_DIR"

# Xcode Cloud clones shallowly; deepen enough to describe the last few changes.
git fetch --deepen 20 --quiet 2>/dev/null || true

{
  echo "Pip build ${CI_BUILD_NUMBER:-?} · $(git rev-parse --short HEAD) on ${CI_BRANCH:-${CI_TAG:-main}}"
  echo
  echo "Recent changes:"
  git log -12 --pretty=format:"• %s" | sed -E 's/^• (feat|fix|design|chore|ci|docs|test|polish|refactor)(\([^)]*\))?: /• /'
  echo
  echo
  echo "Please try: log a mood from the Pet tab, sit with your pet for a minute, check the widgets and the History tab. Reply with anything that feels off."
} > "$NOTES_DIR/WhatToTest.en-US.txt"

echo "== TestFlight notes"
cat "$NOTES_DIR/WhatToTest.en-US.txt"
