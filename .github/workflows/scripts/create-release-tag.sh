#!/usr/bin/env bash
set -euo pipefail

MARKETING_VERSION=$(awk '
  /MARKETING_VERSION = / { line=$0; sub(/^.*MARKETING_VERSION = /, "", line); sub(/;.*$/, "", line); last=line }
  /PRODUCT_BUNDLE_IDENTIFIER = mmo\.catchrecordingdev\.ios;/ { print last; exit }
' record-catch.xcodeproj/project.pbxproj)

PROJECT_BUILD=$(awk '
  /CURRENT_PROJECT_VERSION = / { line=$0; sub(/^.*CURRENT_PROJECT_VERSION = /, "", line); sub(/;.*$/, "", line); last=line }
  /PRODUCT_BUNDLE_IDENTIFIER = mmo\.catchrecordingdev\.ios;/ { print last; exit }
' record-catch.xcodeproj/project.pbxproj)

if [[ -z "${MARKETING_VERSION}" || -z "${PROJECT_BUILD}" ]]; then
  echo "::error::Could not read MARKETING_VERSION or CURRENT_PROJECT_VERSION from project.pbxproj" >&2
  exit 1
fi

TAG_NAME="v${MARKETING_VERSION}-BUILD_${PROJECT_BUILD}"

# Validate if tag already exists on remote
if git ls-remote --tags origin "refs/tags/${TAG_NAME}" | grep -q "refs/tags/${TAG_NAME}$"; then
  echo "::error::Tag '${TAG_NAME}' already exists on remote. Increment CURRENT_PROJECT_VERSION in project.pbxproj before merging to main." >&2
  exit 1
fi

echo "Creating and pushing release tag: ${TAG_NAME}"
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git tag "${TAG_NAME}"
git push origin "${TAG_NAME}"
