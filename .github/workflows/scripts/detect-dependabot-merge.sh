#!/usr/bin/env bash
# Outputs dependabot=true when the pushed commit was merged from a Dependabot PR (squash, merge or rebase alike).
set -euo pipefail

PR_AUTHORS="$(gh api "repos/${GITHUB_REPOSITORY}/commits/${GITHUB_SHA}/pulls" --jq '.[].user.login')"

if grep -qx 'dependabot\[bot\]' <<< "$PR_AUTHORS"; then
  echo "Commit ${GITHUB_SHA} came from a Dependabot PR: no release tag; it ships with the next version bump."
  echo "dependabot=true" >> "$GITHUB_OUTPUT"
else
  echo "dependabot=false" >> "$GITHUB_OUTPUT"
fi
