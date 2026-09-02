#!/bin/bash
# Regenerates the offline map's precomputed `.plist` resources from the bundled `.geojson`
# sources, by running the real production Map parsing/reprojection/sea-overlap code (not a
# reimplementation) as a standalone macOS command-line script via `swift`.
#
# Run automatically by the "Generate Precomputed Map Data" build phase on the record-catch target
# (see Xcode target build phases) — Xcode only re-runs it when a `.geojson` input has changed
# (declared input/output files enable incremental-build skipping). Can also be run manually:
#
#   scripts/generate-offline-map-data.sh
#
# See docs/development/offline-map-precomputed-data.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAP_DIR="$REPO_ROOT/record-catch/Features/Map"
DATA_DIR="$MAP_DIR/Data"
BIN_PATH="$(mktemp -t generate-offline-map-data)"

# This script is also invoked from an Xcode "Run Script" build phase on the iOS app target, whose
# build environment exports iOS-Simulator SDK/arch settings (SDKROOT, arch, etc.). Those must NOT
# leak into this invocation: this is a host-side, macOS-only data-generation tool, not part of the
# iOS app build. Clear the inherited SDK/arch/target env vars and target the host macOS SDK
# explicitly so `swiftc` always builds a macOS command-line binary regardless of the calling
# context (Xcode build phase vs. a plain Terminal invocation).
unset SDKROOT
unset ARCHS
unset ARCHS_STANDARD
unset PLATFORM_NAME
unset SWIFT_PLATFORM_TARGET_PREFIX
unset DEPLOYMENT_TARGET_CLANG_ENV_NAME
unset SWIFT_DEPLOYMENT_TARGET
unset IPHONEOS_DEPLOYMENT_TARGET
MACOSX_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
HOST_ARCH="$(uname -m)"

swiftc \
  -sdk "$MACOSX_SDK_PATH" \
  -target "${HOST_ARCH}-apple-macosx13.0" \
  "$MAP_DIR/OfflineMapDataError.swift" \
  "$MAP_DIR/GeoJSONBundleLoader.swift" \
  "$MAP_DIR/GeoJSONGeometryConversion.swift" \
  "$MAP_DIR/GeoJSONPropertiesDecoder.swift" \
  "$MAP_DIR/SubrectangleProperties.swift" \
  "$MAP_DIR/PointInPolygon.swift" \
  "$MAP_DIR/MapLandOverlay.swift" \
  "$MAP_DIR/MapLandLoader.swift" \
  "$MAP_DIR/SubrectangleAnnotation.swift" \
  "$MAP_DIR/SubrectangleOverlay.swift" \
  "$MAP_DIR/SubrectangleLoader.swift" \
  "$MAP_DIR/PortMarker.swift" \
  "$MAP_DIR/PortLoader.swift" \
  "$MAP_DIR/SubrectangleSeaOverlap.swift" \
  "$MAP_DIR/PrecomputedMapData.swift" \
  "$SCRIPT_DIR/main.swift" \
  -o "$BIN_PATH"

"$BIN_PATH" "$DATA_DIR"
rm -f "$BIN_PATH"
