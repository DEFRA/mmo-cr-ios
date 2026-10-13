#!/usr/bin/env bash
# PR-time guard: a merged PR must produce a new, higher release tag. Dependabot PRs are skipped by the workflow.
set -euo pipefail
# shellcheck source=lib/project-version.sh
source "$(dirname "$0")/lib/project-version.sh"

fail() {
  echo "::error file=${PBXPROJ}::$1" >&2
  exit 1
}

read -r VERSION BUILD <<< "$(read_project_version "$PBXPROJ")"
[[ -n "${VERSION:-}" && -n "${BUILD:-}" ]] || fail "Could not read MARKETING_VERSION / CURRENT_PROJECT_VERSION"
[[ "$BUILD" =~ ^[0-9]+$ ]] || fail "CURRENT_PROJECT_VERSION '${BUILD}' must be a whole number"
TAG="v${VERSION}-BUILD_${BUILD}"

set +e
git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null
TAG_LOOKUP=$?
set -e
case "$TAG_LOOKUP" in
  0) fail "Release tag ${TAG} already exists. Bump CURRENT_PROJECT_VERSION (and MARKETING_VERSION if needed)." ;;
  2) ;;
  *) fail "Could not query remote tags (git exit ${TAG_LOOKUP}); refusing to assume ${TAG} is new." ;;
esac

# Compare with the latest target branch so a PR that is behind can't reuse a number already merged.
BASE_FILE="$(mktemp)"
git show "origin/${GITHUB_BASE_REF:?}:${PBXPROJ}" > "$BASE_FILE"
read -r BASE_VERSION BASE_BUILD <<< "$(read_project_version "$BASE_FILE")"
rm -f "$BASE_FILE"

LOWEST="$(printf '%s\n%s\n' "$VERSION" "$BASE_VERSION" | sort -V | head -n1)"
if [[ "$VERSION" != "$BASE_VERSION" && "$LOWEST" == "$VERSION" ]]; then
  fail "MARKETING_VERSION ${VERSION} is lower than ${BASE_VERSION} on ${GITHUB_BASE_REF}."
fi
if [[ "$VERSION" == "$BASE_VERSION" && "$BASE_BUILD" =~ ^[0-9]+$ ]] && (( BUILD <= BASE_BUILD )); then
  fail "CURRENT_PROJECT_VERSION ${BUILD} must be higher than ${BASE_BUILD} on ${GITHUB_BASE_REF} (version ${VERSION})."
fi

echo "Version bump OK: ${GITHUB_BASE_REF} has ${BASE_VERSION} (${BASE_BUILD}); merging this PR will publish ${TAG}."
