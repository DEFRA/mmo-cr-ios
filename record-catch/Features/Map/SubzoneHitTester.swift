import MapKit

/// Finds which subzone (if any) a map coordinate falls inside.
///
/// Kept separate from `SeaMapCoordinator` and gesture recognizers so it can
/// be unit tested directly with plain coordinates and overlays.
enum SubzoneHitTester {

    /// Returns the `sub_code` of the topmost subzone overlay containing `coordinate`, or nil.
    ///
    /// `overlays` should be ordered as they were added to the map — later
    /// elements are treated as drawn on top, matching MapKit's convention.
    static func subzoneCode(at coordinate: CLLocationCoordinate2D, in overlays: [SubzoneOverlay]) -> String? {
        let mapPoint = MKMapPoint(coordinate)

        return overlays
            .reversed()
            .first { $0.contains(mapPoint) }?
            .subCode
    }
}
