import MapKit

/// Chooses the initial camera position for `OfflineMapView` when it should open framed on a
/// specific departure/return port, rather than the whole-UK default view.
///
/// Two decisions, both driven by the fishing-area grid rather than an arbitrary zoom level:
///
/// 1. **Span** — sized to show roughly one ICES statistical rectangle around the port: a 3×3
///    block of the ~1/3° (longitude) × 1/6° (latitude) subrectangles that make up the grid (see
///    `subrectangles.geojson`'s real feature extents), i.e. "roughly 9" subrectangles, with a
///    small margin so the outer ring isn't clipped at the view's edge.
/// 2. **Centre** — deliberately **not** the port itself. Most ports sit right on the coastline,
///    so centring on the port would waste roughly half the view on land the user can't fish in.
///    Instead the centre is nudged a little towards whichever compass direction has the most open
///    sea nearby (sampled against the bundled land layer — see `MapLandLoader`), so the port ends
///    up nearer the land-side edge of the view and the sea subrectangles alongside it — the ones
///    the user is actually choosing between — fill most of the frame.
///
/// If the land layer can't be loaded, or every sampled direction is land (or there's no port to
/// frame at all), this degrades to the caller's own default region / a camera centred exactly on
/// the port — never a crash, matching the rest of the offline map's fail-soft loading.
enum PortMapCamera {

    /// Sized to show roughly one ICES statistical rectangle (~9 subrectangles) around a port.
    static let subrectangleGridSpan = MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 1.05)

    /// How far (as a fraction of the half-span) the camera centre is nudged from the port towards
    /// open sea. Kept modest so the port always stays comfortably on-screen, never clipped at the
    /// view's edge.
    private static let seaBiasFraction = 0.5

    /// Candidate compass directions to bias towards, as (latitude, longitude) unit-ish vectors.
    /// Order only affects tie-breaking between equally "sea" directions (see `bestSeaDirection`).
    private static let compassDirections: [(dLat: Double, dLon: Double)] = {
        let diagonal = 1 / (2.0).squareRoot()
        return [
            (dLat: 1, dLon: 0), (dLat: diagonal, dLon: diagonal),
            (dLat: 0, dLon: 1), (dLat: -diagonal, dLon: diagonal),
            (dLat: -1, dLon: 0), (dLat: -diagonal, dLon: -diagonal),
            (dLat: 0, dLon: -1), (dLat: diagonal, dLon: -diagonal)
        ]
    }()

    /// Sample distances (as a fraction of the half-span) tested along each candidate direction.
    private static let sampleFractions: [Double] = [0.2, 0.4, 0.6]

    /// Full pipeline for a real screen: loads the bundled land layer (precomputed, falling back to
    /// the raw `map.geojson` — mirrors `OfflineMapView`'s own fallback) and frames `portCoordinate`,
    /// or returns `defaultRegion` unchanged when there's no port to frame (e.g. none selected yet).
    static func initialRegion(
        forPort portCoordinate: PortCoordinate?,
        defaultRegion: MKCoordinateRegion,
        span: MKCoordinateSpan = subrectangleGridSpan,
        bundle: Bundle = .main
    ) -> MKCoordinateRegion {
        guard let portCoordinate else { return defaultRegion }

        let coordinate = CLLocationCoordinate2D(latitude: portCoordinate.latitude, longitude: portCoordinate.longitude)
        return region(forPort: coordinate, avoiding: loadLandOverlays(bundle: bundle), span: span)
    }

    /// Pure framing logic, exposed for unit testing with injected land overlays (no bundle I/O).
    static func region(
        forPort portCoordinate: CLLocationCoordinate2D,
        avoiding landOverlays: [MapLandOverlay],
        span: MKCoordinateSpan = subrectangleGridSpan
    ) -> MKCoordinateRegion {
        MKCoordinateRegion(center: biasedCenter(near: portCoordinate, span: span, landOverlays: landOverlays), span: span)
    }

    private static func biasedCenter(
        near portCoordinate: CLLocationCoordinate2D,
        span: MKCoordinateSpan,
        landOverlays: [MapLandOverlay]
    ) -> CLLocationCoordinate2D {
        guard let direction = bestSeaDirection(from: portCoordinate, span: span, landOverlays: landOverlays) else {
            return portCoordinate
        }

        return CLLocationCoordinate2D(
            latitude: portCoordinate.latitude + direction.dLat * (span.latitudeDelta / 2) * seaBiasFraction,
            longitude: portCoordinate.longitude + direction.dLon * (span.longitudeDelta / 2) * seaBiasFraction
        )
    }

    /// The direction with the most non-land sample points near `portCoordinate`, or `nil` when
    /// there's no land data to judge by, when no direction has any sea sample, or when every
    /// direction is equally "sea" (nothing nearby to steer away from) — in each of those cases the
    /// caller leaves the camera centred on the port itself rather than guessing a direction.
    ///
    /// When several compass directions **tie** for the best score (a common, symmetric case — e.g.
    /// a coastline running due north–south, where east and every north/south-leaning direction all
    /// score equally "sea"), this averages their vectors rather than arbitrarily picking the first
    /// one on the list. Averaging lets opposing components cancel (e.g. a north-leaning and a
    /// south-leaning tie cancel to a due-east bias), which is what naturally happens for a straight
    /// coastline and avoids an arbitrary, uneven-looking drift along the coast.
    private static func bestSeaDirection(
        from portCoordinate: CLLocationCoordinate2D,
        span: MKCoordinateSpan,
        landOverlays: [MapLandOverlay]
    ) -> (dLat: Double, dLon: Double)? {
        guard !landOverlays.isEmpty else { return nil }

        let halfLat = span.latitudeDelta / 2
        let halfLon = span.longitudeDelta / 2

        let scoredDirections = compassDirections.map { direction -> (direction: (dLat: Double, dLon: Double), score: Int) in
            let score = sampleFractions.reduce(into: 0) { score, fraction in
                let sample = CLLocationCoordinate2D(
                    latitude: portCoordinate.latitude + direction.dLat * halfLat * fraction,
                    longitude: portCoordinate.longitude + direction.dLon * halfLon * fraction
                )
                if !isLand(sample, landOverlays: landOverlays) {
                    score += 1
                }
            }
            return (direction, score)
        }

        guard let maxScore = scoredDirections.map(\.score).max(), maxScore > 0 else { return nil }

        // Every direction scored the same (e.g. open sea in every direction, with no nearby land at
        // all) — there's nothing to steer away from, so leave the camera centred on the port.
        guard let minScore = scoredDirections.map(\.score).min(), minScore != maxScore else { return nil }

        let bestDirections = scoredDirections.filter { $0.score == maxScore }.map(\.direction)
        return (
            dLat: bestDirections.map(\.dLat).reduce(0, +) / Double(bestDirections.count),
            dLon: bestDirections.map(\.dLon).reduce(0, +) / Double(bestDirections.count)
        )
    }

    private static func isLand(_ coordinate: CLLocationCoordinate2D, landOverlays: [MapLandOverlay]) -> Bool {
        let point = MKMapPoint(coordinate)
        return landOverlays.contains { land in
            land.boundingMapRect.contains(point) && land.multiPolygon.polygons.contains { $0.containsSubrectanglePoint(point) }
        }
    }

    /// Loads the land layer for sea-direction sampling only — never rendered itself here. Prefers
    /// the precomputed bundled resource (see `PrecomputedMapLoader`) and falls back to parsing the
    /// raw `map.geojson` live, matching `OfflineMapView`'s own land-layer fallback. A missing or
    /// corrupt resource degrades to no land data (logged), which simply means the camera centres
    /// on the port with no directional bias — never a crash.
    private static func loadLandOverlays(bundle: Bundle) -> [MapLandOverlay] {
        if let overlays = try? PrecomputedMapLoader.loadBundledLand(bundle: bundle) {
            return overlays
        }

        do {
            return try MapLandLoader.loadBundled(bundle: bundle)
        } catch {
            OfflineMapLogger.logLoadFailure(layer: "map", error: error)
            return []
        }
    }
}
