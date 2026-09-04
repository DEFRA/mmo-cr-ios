#!/usr/bin/env bash
set -euo pipefail

XCRESULT="$(find fastlane/test_output -maxdepth 2 -name '*.xcresult' 2>/dev/null | head -n1 || true)"
if [ -z "$XCRESULT" ]; then
  echo "::error::No .xcresult bundle found under fastlane/test_output" >&2
  exit 1
fi

bash scripts/xccov-to-sonarqube-generic.sh "$XCRESULT" > sonar-coverage.xml
