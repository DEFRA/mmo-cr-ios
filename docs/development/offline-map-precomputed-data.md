# Offline map: precomputed data

> For the full component overview (layers, styling, interaction model, cross-platform notes for
> the Android team), see [offline-map-overview.md](offline-map-overview.md). This document covers
> only the precomputed-data pipeline in detail.

`OfflineMapView` ships three **precomputed** resources alongside the raw source GeoJSON:

```
record-catch/Features/Map/Data/
├── map.geojson                        # source (main map / land polygons)
├── map-precomputed.plist              # generated
├── subrectangles.geojson              # source (subrectangle boundaries + labels)
├── subrectangles-precomputed.plist    # generated
├── ports.geojson                      # source (port locations)
└── ports-precomputed.plist            # generated
```

## Why

`map.geojson`/`subrectangles.geojson`/`ports.geojson` are static — they never change at runtime.
Parsing them (JSON decoding, the Web Mercator/numeric-string coordinate reprojection fallback in
`RawGeoJSONGeometry`) and computing which subrectangles overlap the sea (`SubrectangleSeaOverlap`,
a ~25-point sample per subrectangle against the land layer) is a fixed function of that static
data. Doing this once, offline, and shipping the *result* as a bundled resource means the app never
repeats that work — not once per launch, and not once per catch record (the most common way this
map is actually shown, via `CatchLocationView`).

At runtime, `OfflineMapView` loads the precomputed `.plist` resources via `PrecomputedMapLoader`
(a straight `PropertyListDecoder` decode — no JSON parsing, no reprojection, no sea-overlap
sampling). If a precomputed resource is ever missing, it falls back to parsing the raw `.geojson`
live (`MapLandLoader`/`SubrectangleLoader`/`PortLoader` + `SubrectangleSeaOverlap`), exactly as the
map worked before precomputed data was introduced — so a missing/stale precomputed file degrades
gracefully rather than breaking the map.

## Regenerating

The three `-precomputed.plist` files are regenerated **automatically** by an Xcode "Run Script"
build phase (`Generate Precomputed Map Data`) on the `record-catch` app target, which runs
`scripts/generate-offline-map-data.sh`. Xcode declares the three source `.geojson` files as the
phase's `inputPaths` and the three `-precomputed.plist` files as its `outputPaths`, so the phase is
skipped automatically when none of the `.geojson` files have changed since the last build (standard
Xcode incremental-build behaviour) — you don't need to remember to run this by hand.

The script compiles the app's real, already-unit-tested Map loaders/`SubrectangleSeaOverlap` plus
`scripts/main.swift` into a standalone macOS command-line binary (`swiftc`) and runs it, so the
generated data always reflects the exact same parsing/reprojection/sea-overlap logic the app itself
uses — not a reimplementation. It explicitly targets the host macOS SDK/architecture (clearing the
iOS-Simulator SDK/arch environment variables Xcode's own build injects), since this is a host-side
data-generation tool, not part of the iOS app build.

You can also run it manually at any time:

```
scripts/generate-offline-map-data.sh
```

This requires `ENABLE_USER_SCRIPT_SANDBOXING = NO` on the `record-catch` target only (both Debug
and Release configs; the project default of `YES` is unchanged everywhere else), so the script can
invoke `swiftc` and read its own source files — see the comment beside that build setting in
`project.pbxproj`.

After regenerating (automatically via a build, or manually), rebuild and re-run the Map test suite
(`PrecomputedMapLoaderTests`, `PrecomputedMapDataTests`, `OfflineMapCoordinatorTests`, plus the
existing GeoJSON-loader tests) to confirm the new data parses correctly and the feature counts
match the source GeoJSON.

## Format

Each `-precomputed.plist` is a **binary property list** (`PropertyListEncoder`/`.binary`) encoding
the `PrecomputedMapData` Codable models (see that file's doc comments) — plain `Double`-based
coordinate/polygon structures, not `MKPolygon`/`CLLocationCoordinate2D` directly, so they round-trip
losslessly through `Codable`. `PrecomputedMapLoader` reconstructs the real `MapLandOverlay`/
`SubrectangleOverlay`/`PortMarker`/`SubrectangleAnnotation` types the map actually renders.

The subrectangle layer also carries a precomputed `overlapsSea: Bool` per feature (see
`SubrectangleSeaOverlap`) — a purely inland subrectangle is still included (its grid boundary is
still drawn), but is excluded from labelling and tap-selection.
