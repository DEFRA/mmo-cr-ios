#!/bin/bash
#
# Runs SwiftLint across the whole project.
#
# Usage:
#   scripts/swiftlint.sh          # lint (used by CI and pre-commit)
#   scripts/swiftlint.sh --fix    # auto-correct fixable violations locally
#
# Requires SwiftLint installed via Homebrew (SPM app dependencies are kept
# separate from this dev tool per the project's SPM-only dependency policy):
#   brew install swiftlint

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "error: swiftlint is not installed. Run 'brew install swiftlint' and try again." >&2
  exit 1
fi

# Lints app source, unit tests and UI tests as three separate passes, each
# with its own explicit config. SwiftLint's --config flag replaces (rather
# than merges with) any nested .swiftlint.yml discovered by directory walk,
# so each scope's config is self-contained (test fixtures may use
# force-unwrap/try/cast and short identifiers such as the ID
# accessibility-identifier enum, which app source must not).
#
# Each scope also has a committed baseline (.swiftlint-baselines/*.json)
# generated when SwiftLint was first introduced, so pre-existing violations
# in this legacy codebase don't block CI on day one - but ANY NEW violation
# still fails the build/lint. Shrink the baseline over time by fixing an
# existing violation and regenerating it (see README).
cd "${REPO_ROOT}"

MODE="lint"
USE_BASELINE=1
if [ "${1:-}" = "--fix" ]; then
  MODE="lint --fix"
  # --fix ignores baselines and corrects everything it safely can.
  USE_BASELINE=0
fi

status=0

app_args=(swiftlint $MODE --strict --config "${REPO_ROOT}/.swiftlint.yml")
tests_args=(swiftlint $MODE --strict --config "${REPO_ROOT}/record-catchTests/.swiftlint.yml")
uitests_args=(swiftlint $MODE --strict --config "${REPO_ROOT}/record-catchUITests/.swiftlint.yml")

if [ "$USE_BASELINE" = "1" ]; then
  app_args+=(--baseline "${REPO_ROOT}/.swiftlint-baselines/app.json")
  tests_args+=(--baseline "${REPO_ROOT}/.swiftlint-baselines/tests.json")
  uitests_args+=(--baseline "${REPO_ROOT}/.swiftlint-baselines/uitests.json")
fi

"${app_args[@]}" "${REPO_ROOT}/record-catch" || status=1
"${tests_args[@]}" "${REPO_ROOT}/record-catchTests" || status=1
"${uitests_args[@]}" "${REPO_ROOT}/record-catchUITests" || status=1

exit $status
