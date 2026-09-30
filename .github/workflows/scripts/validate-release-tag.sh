#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib/project-version.sh
source "$(dirname "$0")/lib/project-version.sh"

read -r PROJECT_VERSION PROJECT_BUILD <<< "$(read_project_version "$PBXPROJ")"

if [[ -z "${PROJECT_VERSION}" || -z "${PROJECT_BUILD}" ]]; then
  echo "::error::Could not read MARKETING_VERSION or CURRENT_PROJECT_VERSION from project.pbxproj" >&2
  exit 1
fi

# The version comes only from the code: the run must be on the tag that code produces, never a branch or override.
EXPECTED_TAG="v${PROJECT_VERSION}-BUILD_${PROJECT_BUILD}"

if [[ "${GITHUB_REF_TYPE:-}" != "tag" ]]; then
  echo "::error::Run iOS Release on a release tag (Use workflow from → Tags → ${EXPECTED_TAG}), not the branch '${GITHUB_REF_NAME:-}'." >&2
  exit 1
fi

if [[ "${GITHUB_REF_NAME:-}" != "${EXPECTED_TAG}" ]]; then
  echo "::error::Tag ${GITHUB_REF_NAME:-} does not match the version in the code at that tag (${EXPECTED_TAG})." >&2
  exit 1
fi

echo "Releasing ${EXPECTED_TAG}: version ${PROJECT_VERSION}, build ${PROJECT_BUILD}, taken from the code at the tag."
