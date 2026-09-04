import MapKit

/// Finds which subrectangle (if any) a map coordinate falls inside.
///
/// Kept separate from `OfflineMapCoordinator` and gesture recognizers so it can be unit tested
/// directly with plain coordinates and overlays. Only ever consulted with subrectangle overlays —
/// the main map layer and ports are structurally excluded from hit testing (they're never passed
/// in), so they can never be "selected" regardless of where the user taps.
enum SubrectangleHitTester {

    /// Returns the topmost subrectangle overlay containing `coordinate`, or nil.
    ///
    /// `overlays` should be ordered as they were added to the map — later elements are treated as
    /// drawn on top, matching MapKit's convention.
    static func subrectangle(at coordinate: CLLocationCoordinate2D, in overlays: [SubrectangleOverlay]) -> SubrectangleOverlay? {
        let mapPoint = MKMapPoint(coordinate)

        return overlays
            .reversed()
            .first { $0.contains(mapPoint) }
    }
}
