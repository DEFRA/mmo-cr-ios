#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib/project-version.sh
source "$(dirname "$0")/lib/project-version.sh"

read -r MARKETING_VERSION PROJECT_BUILD <<< "$(read_project_version "$PBXPROJ")"

if [[ -z "${MARKETING_VERSION}" || -z "${PROJECT_BUILD}" ]]; then
  echo "::error::Could not read MARKETING_VERSION or CURRENT_PROJECT_VERSION from project.pbxproj" >&2
  exit 1
fi

TAG_NAME="v${MARKETING_VERSION}-BUILD_${PROJECT_BUILD}"

REMOTE_REFS="$(git ls-remote --tags origin "refs/tags/${TAG_NAME}" "refs/tags/${TAG_NAME}^{}")"
if [[ -n "${REMOTE_REFS}" ]]; then
  # The peeled ^{} line (annotated tags) sorts last and is the commit; a lightweight tag has only one line.
  TAGGED_COMMIT="$(tail -n1 <<< "${REMOTE_REFS}" | cut -f1)"
  if [[ "${TAGGED_COMMIT}" == "$(git rev-parse HEAD)" ]]; then
    echo "Tag '${TAG_NAME}' already points at this commit; nothing to do."
    exit 0
  fi
  echo "::error::Tag '${TAG_NAME}' already exists on another commit (${TAGGED_COMMIT}). Increment CURRENT_PROJECT_VERSION in project.pbxproj before merging to main." >&2
  exit 1
fi

echo "Creating and pushing release tag: ${TAG_NAME}"
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git tag "${TAG_NAME}"
git push origin "${TAG_NAME}"
