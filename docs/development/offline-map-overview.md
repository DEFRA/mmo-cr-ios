# Offline Fisheries Map — component overview

A cross-team explainer for the native iOS `OfflineMapView` component, written to be handed to
another platform team (e.g. Android) implementing an equivalent map. For iOS-specific
implementation detail on the precomputed data pipeline specifically, see
[offline-map-precomputed-data.md](offline-map-precomputed-data.md).

## 1. Goal & non-negotiables

A fully offline map showing three data layers over the UK fishing grounds. **No Apple Maps/Google
Maps/Mapbox/OSM tiles, no network requests at all** — the "base map" itself is synthesised
in-memory as a solid white 1×1 pixel tile (see §4), so there's nothing underneath our own layers
that could ever need connectivity.

## 2. Source data — three GeoJSON files, WGS84 (EPSG:4326)

Bundled in the app under `record-catch/Features/Map/Data/`:

| File | Geometry | Key properties | Feature count |
|---|---|---|---|
| `map.geojson` | Polygon/MultiPolygon (land masses) | — | 7 |
| `subrectangles.geojson` | Polygon/MultiPolygon (ICES statistical subrectangles) | `sub_code` (e.g. `"27D86"`, stable ID), `ICESNAME` (parent rectangle, e.g. `"27D8"`), `AREA_KM2`, `stat_x`/`stat_y` (parent rectangle's *centre* — **not** unique per subrectangle, see gotcha below) | 3,465 |
| `ports.geojson` | Point | `port_code` (numeric ID), `port` (display name), `lat`/`long_` | 938 |

**⚠️ Real-world data-quality gotcha you should know about (may also affect your Android
parser):** the actual `subrectangles.geojson` ring vertices are encoded in **Web Mercator
(EPSG:3857) metres**, not WGS84 degrees — even though the same features' own `stat_x`/`stat_y`
properties *are* correct WGS84 degrees. Some coordinate components are also encoded as **JSON
strings** rather than numbers (e.g. `"-1264519.10..."`). Our parser: (1) accepts numeric strings as
well as JSON numbers, (2) tries the value as WGS84 degrees first, and (3) if invalid,
inverse-projects it as Web Mercator metres and validates the result. Without step 3, essentially
the entire subrectangles layer fails to parse. Worth confirming whether your Android GeoJSON
library has the same issue.

## 3. Two-stage pipeline: build-time precompute → runtime load

This is the most important architectural point. **iOS does almost zero work at runtime.**

### Stage A — build-time precompute (automated)

An Xcode "Run Script" build phase (`Generate Precomputed Map Data`) runs on every build, comparing
file timestamps: if none of the 3 source `.geojson` files changed since last build, it's skipped
(standard incremental build). When it does run, it:

1. Compiles the app's actual production Swift loader code (GeoJSON parsing, the Web-Mercator-
   fallback reprojection, coordinate validation) into a **standalone macOS command-line binary**
   via `swiftc`.
2. Runs that binary, which also computes, once, **which subrectangles have any real sea area**
   (see "sea overlap" below).
3. Writes the result as three binary property-list files: `map-precomputed.plist` (327KB),
   `subrectangles-precomputed.plist` (599KB, down from 2.1MB source), `ports-precomputed.plist`
   (46KB) — plain `Double`-based coordinate/polygon structs, no platform-specific types.

Why: parsing + reprojection + the sea-overlap sampling (~25 point-in-polygon tests × 3,465
subrectangles against 7 land polygons) is a fixed function of static data. Doing it once at build
time means it's never repeated — not per app launch, and not every time a user opens the
catch-recording map screen (the most frequent case).

See [offline-map-precomputed-data.md](offline-map-precomputed-data.md) for the full iOS-specific
detail (file format, manual regeneration, build-phase wiring).

### Stage B — runtime load (fast path)

At runtime, the app just does a straight binary-plist decode of the three `-precomputed.plist`
files — no JSON parsing, no reprojection, no point-in-polygon sampling. If a precomputed file is
ever missing/corrupt, it falls back to parsing the raw `.geojson` live (same logic as Stage A, just
running on-device) — so nothing crashes, it's just slower that one time.

**Android equivalent recommendation:** if you don't already have an offline preprocessing step,
consider doing the same — precompute corrected WGS84 coordinates + the sea-overlap flag once (a
script, a Gradle task, whatever fits) and ship a lightweight derived format, rather than
parsing/reprojecting/sampling the raw GeoJSON on every app run.

## 4. Rendering layers (draw order, bottom → top)

1. **Blank base tile** — a single solid-colour (white) 1×1 pixel PNG synthesised in memory and
   returned synchronously for every tile request (`MKTileOverlay` subclass with
   `urlTemplate: nil`, `canReplaceMapContent = true`). This is what fully replaces Apple's base
   map — including its own inland town/city labels (important: had to draw this at the topmost
   "above labels" tier, not the more obvious "above roads" tier, or Apple's own labels still bled
   through).
2. **Land layer** (`map.geojson`) — solid fill `#0B4143`, thin black outline (`1px / zoomScale` so
   it stays visually thin at any zoom).
3. **Subrectangle grid** — thin dark-green (`#0B6B3A`) stroke, near-transparent fill (6% alpha) so
   the map underneath stays visible. **Selected** subrectangle: amber (`#E8A63A`), thicker stroke
   (3px vs 1px), 35% alpha fill — deliberately not red, to avoid an alarm/error connotation.
4. **Subrectangle labels** — the subrectangle's own `sub_code`, positioned at that subrectangle's
   own bounding-box centroid (**not** `stat_x`/`stat_y`, which is shared by every sibling in the
   same parent rectangle and would stack every sibling's label on the same point — a real bug we
   found and fixed). Only shown once zoomed in past a `latitudeDelta < 1.0` threshold, to avoid
   clutter at low zoom.
5. **Ports** — small `#01FEE2` dots (radius scales inversely with zoom to stay a constant
   on-screen size), each with its name drawn as real vector text (Core Text glyphs via
   `NSString.draw`, not a raster bitmap) next to the dot, also gated behind the same zoom threshold
   as subrectangle labels.

A `1.5pt` black border is drawn around the whole map view itself (a UIKit `CALayer` border, not a
map layer).

## 5. Interaction model

- **Ports are 100% display-only.** Not tap-selectable, no callout. Technically: all 938 ports are
  drawn inside a *single* custom overlay/renderer, not as 938 individual annotation views — this
  both guarantees non-interactivity (there's nothing there for the OS to hit-test against) and
  keeps performance high (no per-port view allocation/reuse-queue churn).
- **Subrectangles are tap-selectable.** A tap gesture recognizer converts the tap point to a map
  coordinate, then does point-in-polygon hit-testing against the subrectangle polygons (only the
  "sea-overlapping" subset, see below). Tapping outside every subrectangle clears the selection.
  Selection is exposed to the parent screen via a two-way binding of a `SubrectangleProperties`
  struct (essentially: "here's the sub_code + a few other fields the user picked, or `nil`").
- **Sea-overlap filtering:** a subrectangle is excluded from *labelling and selection* — but its
  grid boundary is still drawn — if a 5×5 sample grid across its bounding box lands entirely inside
  a land polygon (bounding-rect pre-filtering keeps this cheap). This correctly still treats a
  coastal subrectangle that straddles the coastline as sea-overlapping (only fully-inland ones are
  excluded).

## 6. Initial camera position (caller-controlled, never auto-fit)

The component takes an explicit `initialCoordinate` + `initialSpan` (~centre + zoom) from the
caller, applied exactly once when the native map view is created. It never
recomputes/refits the camera from the GeoJSON extent, and it never resets the user's subsequent
pan/zoom on further SwiftUI state updates — this was an explicit requirement, worth replicating on
Android (e.g. don't call anything like a "zoom to bounds" on every view recomposition).

## 7. Performance characteristics worth knowing

- Parsing/reprojection/sea-overlap sampling is now a build-time cost, not a runtime one (see §3).
- Overlay renderers cull to only what's inside the current tile's `mapRect` before drawing (ports
  especially — draw cost scales with what's on screen, not the full 938).
- Selection changes only touch the specific renderer/view whose selection state actually changed
  (not a full-map redraw).
- Label/name text is real vector-font glyph drawing, not per-feature UIKit views, at least for
  ports — this avoids ~900 extra interactive view objects. (Subrectangle labels *do* use one
  lightweight annotation view each, but only ~2,857 sea-overlapping ones, and only rendered when
  zoomed in past the visibility threshold.)

## 8. Suggested equivalent Android stack

Not part of this iOS work, but as a rough cross-reference: MapKit's role here (tile overlay
replacement + custom overlay renderers + point/polygon hit-testing) maps conceptually to Android's
`GoogleMap`/OSMDroid/Mapbox equivalents being deliberately **not used**; instead something like a
raw `Canvas`-based custom view, or MapLibre/OSMDroid configured with a fully offline/no-network
tile provider, would be the equivalent approach — the key architectural decisions to carry over
are:

1. Precompute corrected/derived data once, ship it as a lightweight bundled resource.
2. Keep ports non-interactive by design (single overlay, not per-item views).
3. Never auto-fit the camera to data extent.
4. Apply the same Web-Mercator-reprojection fallback if your GeoJSON parser rejects the same data.
