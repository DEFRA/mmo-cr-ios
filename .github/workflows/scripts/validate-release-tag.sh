#!/usr/bin/env bash
set -euo pipefail

# Read the app target's MARKETING_VERSION & CURRENT_PROJECT_VERSION
PROJECT_VERSION=$(awk '
  /MARKETING_VERSION = / { line=$0; sub(/^.*MARKETING_VERSION = /, "", line); sub(/;.*$/, "", line); last=line }
  /PRODUCT_BUNDLE_IDENTIFIER = mmo\.catchrecordingdev\.ios;/ { print last; exit }
' record-catch.xcodeproj/project.pbxproj)
PROJECT_BUILD=$(awk '
  /CURRENT_PROJECT_VERSION = / { line=$0; sub(/^.*CURRENT_PROJECT_VERSION = /, "", line); sub(/;.*$/, "", line); last=line }
  /PRODUCT_BUNDLE_IDENTIFIER = mmo\.catchrecordingdev\.ios;/ { print last; exit }
' record-catch.xcodeproj/project.pbxproj)

if [[ -z "${PROJECT_VERSION}" || -z "${PROJECT_BUILD}" ]]; then
  echo "::error::Could not read MARKETING_VERSION or CURRENT_PROJECT_VERSION from project.pbxproj" >&2
  exit 1
fi

# On tag pushes, validate tag matches project MARKETING_VERSION and optional BUILD suffix.
# Convention: v<marketing_version>-BUILD_<current_project_version> (e.g. v2.0.0-BUILD_9) or v<marketing_version>
if [[ "${GITHUB_REF_TYPE:-}" == "tag" && "${GITHUB_REF_NAME:-}" == v* ]]; then
  TAG_RAW="${GITHUB_REF_NAME#v}"
  if [[ "${TAG_RAW}" =~ ^([^-]+)-BUILD_(.+)$ ]]; then
    TAG_VERSION="${BASH_REMATCH[1]}"
    TAG_BUILD="${BASH_REMATCH[2]}"
    if [[ "${TAG_VERSION}" != "${PROJECT_VERSION}" ]]; then
      echo "::error::Tag marketing version ${TAG_VERSION} does not match project MARKETING_VERSION ${PROJECT_VERSION}" >&2
      exit 1
    fi
    if [[ "${TAG_BUILD}" != "${PROJECT_BUILD}" ]]; then
      echo "::error::Tag build number ${TAG_BUILD} does not match project CURRENT_PROJECT_VERSION ${PROJECT_BUILD}" >&2
      exit 1
    fi
    echo "Tag ${GITHUB_REF_NAME} matches project version ${PROJECT_VERSION} and build ${PROJECT_BUILD}"
  else
    if [[ "${TAG_RAW}" != "${PROJECT_VERSION}" ]]; then
      echo "::error::Tag version ${TAG_RAW} does not match project MARKETING_VERSION ${PROJECT_VERSION} — align the tag with the app version in project.pbxproj" >&2
      exit 1
    fi
    echo "Tag version ${TAG_RAW} matches project MARKETING_VERSION ${PROJECT_VERSION}"
  fi
elif [[ "${GITHUB_EVENT_NAME:-}" == "workflow_dispatch" ]]; then
  if [[ -n "${INPUT_MARKETING_VERSION:-}" ]]; then
    echo "Using manual marketing_version override: ${INPUT_MARKETING_VERSION}"
  else
    echo "Using project MARKETING_VERSION: ${PROJECT_VERSION}"
  fi
  if [[ -n "${INPUT_PROJECT_VERSION:-}" ]]; then
    echo "Using manual project_version override: ${INPUT_PROJECT_VERSION}"
  else
    echo "Using project CURRENT_PROJECT_VERSION from project.pbxproj"
  fi
else
  echo "::error::Unsupported trigger '${GITHUB_EVENT_NAME:-}' for ${GITHUB_REF_TYPE:-} '${GITHUB_REF_NAME:-}' — push a v* tag or use workflow_dispatch" >&2
  exit 1
fi
