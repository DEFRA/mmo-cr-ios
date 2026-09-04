import MapKit

/// Decides which subrectangles have any real sea area, so purely inland subrectangles — fully
/// covered by the main map's land layer, with no actual fishing area — are excluded from
/// labelling and tap-selection (they still render their grid boundary, like every other
/// subrectangle; only those two behaviours are gated).
///
/// A subrectangle is treated as "entirely on land" only if *every* one of a grid of sample points
/// spanning its bounding rect falls inside the land layer. Any subrectangle with a real sea
/// component — including a coastal one straddling the coastline — therefore still counts as
/// overlapping the sea, matching "in the sea or overlap the sea".
///
/// This is a sampling heuristic, not exact polygon clipping: a subrectangle could in principle
/// contain a sliver of sea too small for the sample grid to land on and be misclassified as
/// land-only. That's an acceptable trade-off here — the main map's land layer has only 7 features
/// (~9.7k vertices total, see `map.geojson`), so this stays cheap even at ~3,500 subrectangles.
enum SubrectangleSeaOverlap {

    /// Sample points per axis, spanning each subrectangle's bounding rect edge-to-edge (0%, 25%,
    /// 50%, 75%, 100%) — a 5×5 grid of 25 points per subrectangle tested against land.
    private static let sampleFractions: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

    /// Returns the subset of `overlays` that overlap the sea (i.e. are **not** entirely covered by
    /// `landOverlays`). Preserves the input order.
    static func overlappingSea(_ overlays: [SubrectangleOverlay], landOverlays: [MapLandOverlay]) -> [SubrectangleOverlay] {
        guard !landOverlays.isEmpty else { return overlays }

        return overlays.filter { !isEntirelyOnLand($0, landOverlays: landOverlays) }
    }

    private static func isEntirelyOnLand(_ overlay: SubrectangleOverlay, landOverlays: [MapLandOverlay]) -> Bool {
        let rect = overlay.boundingMapRect

        // Cheap rejection: only test land polygons whose bounding rect could plausibly cover this
        // subrectangle at all. Most subrectangles are open sea, far from every landmass's bounding
        // rect, so this alone resolves the overwhelming majority of subrectangles without a single
        // point-in-polygon test.
        let candidatePolygons = landOverlays
            .filter { $0.boundingMapRect.intersects(rect) }
            .flatMap { $0.multiPolygon.polygons }

        guard !candidatePolygons.isEmpty else { return false }

        for xFraction in sampleFractions {
            for yFraction in sampleFractions {
                let samplePoint = MKMapPoint(
                    x: rect.minX + rect.width * xFraction,
                    y: rect.minY + rect.height * yFraction
                )

                let isSamplePointOnLand = candidatePolygons.contains { $0.containsSubrectanglePoint(samplePoint) }
                if !isSamplePointOnLand {
                    return false
                }
            }
        }

        return true
    }
}
