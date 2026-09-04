#!/usr/bin/env bash
set -euo pipefail

xcodebuild -version

# The default Xcode's iOS Simulator runtime isn't always pre-cached on the runner image, so fetch it on demand.
if ! xcrun simctl list devices available 2>/dev/null | grep -qE "iPhone 17 \("; then
  echo "iPhone 17 simulator not found — downloading the iOS Simulator platform..."
  xcodebuild -downloadPlatform iOS || true
  if ! xcrun simctl list devices available 2>/dev/null | grep -qE "iPhone 17 \("; then
    echo "::error::iPhone 17 Simulator still unavailable after downloading the iOS platform" >&2
    xcrun simctl list devices available >&2 || true
    exit 1
  fi
fi
