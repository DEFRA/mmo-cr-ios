import MapKit

/// Computes the camera-pan boundary applied to `OfflineMapView`, restricting how far the user can
/// pan away from the map's initial camera position.
///
/// Mirrors `OfflineMapView.cameraZoomRange`'s philosophy: let `MKMapView` enforce the limit
/// natively and continuously (via `MKMapView.cameraBoundary`), rather than hand-rolling a
/// gesture-fighting correction. Unlike the zoom limit (a fixed pair of constants), the pan
/// boundary depends on the *initial* camera position, which is only known per-screen — so this is
/// a small, pure, unit-testable helper rather than a `static let` on `OfflineMapView` itself.
enum MapPanLimit {

    /// Hard pan limit, in metres from the map's initial centre — "about 100 miles" per product
    /// ask (see `OfflineMapView`'s "Panning is hard-limited" note). Converted to metres up front
    /// so `boundaryRegion` can drive
    /// `MKCoordinateRegion(center:latitudinalMeters:longitudinalMeters:)` directly, rather than a
    /// hand-rolled degrees-per-mile conversion (which isn't constant for longitude — it varies
    /// with latitude). Plain hardcoded metres; adjust freely.
    static let maxPanDistance: CLLocationDistance = 100 * 1_609.344 // ≈ 160,934m

    /// The boundary region MapKit uses to restrict panning (see
    /// `MKMapView.CameraBoundary(coordinateRegion:)`), centred on `center` and sized so the
    /// camera's centre can move up to `distance` away from `center`, in any direction, before
    /// MapKit stops it.
    ///
    /// `MKCoordinateRegion(center:latitudinalMeters:longitudinalMeters:)` takes the region's
    /// *full* span (edge-to-edge), so `distance` — a radius from the centre — is doubled here to
    /// get that full span (radius → diameter).
    static func boundaryRegion(
        center: CLLocationCoordinate2D,
        distance: CLLocationDistance = maxPanDistance
    ) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, latitudinalMeters: distance * 2, longitudinalMeters: distance * 2)
    }
}
