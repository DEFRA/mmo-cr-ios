# shellcheck shell=bash
# Shared by the release scripts: one place that knows where the version lives (moves to Base.xcconfig with ADR-0014).
# shellcheck disable=SC2034 # consumed by the scripts that source this file
PBXPROJ="record-catch.xcodeproj/project.pbxproj"

# Prints "<MARKETING_VERSION> <CURRENT_PROJECT_VERSION>" of the Dev app target in the given project.pbxproj.
read_project_version() {
  awk '
    /MARKETING_VERSION = / { m=$0; sub(/^.*MARKETING_VERSION = /, "", m); sub(/;.*$/, "", m) }
    /CURRENT_PROJECT_VERSION = / { b=$0; sub(/^.*CURRENT_PROJECT_VERSION = /, "", b); sub(/;.*$/, "", b) }
    /PRODUCT_BUNDLE_IDENTIFIER = mmo\.catchrecordingdev\.ios;/ { print m, b; exit }
  ' "$1"
}
