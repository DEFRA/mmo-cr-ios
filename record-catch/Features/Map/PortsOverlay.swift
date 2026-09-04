import MapKit

/// A single overlay containing every port marker (dot), drawn in one pass.
///
/// Ports are display-only and must never be selectable or show a callout. Rather than create one
/// `MKAnnotationView` per port dot (~900 of them), all port dots are drawn by one `MKOverlay`/
/// `MKOverlayRenderer` pair. This is both a performance win (no per-view overhead for hundreds of
/// interactive-capable views) and what structurally guarantees the *dots* are non-interactive:
/// `MKOverlay`s aren't selectable via MapKit's annotation-selection machinery, and
/// `OfflineMapCoordinator`'s tap handling only ever consults `SubrectangleHitTester` — this
/// overlay is never passed to it.
///
/// Port **names**, in contrast, are drawn by `PortLabelAnnotationView` — a real `MKAnnotationView`
/// per visible port name, needed so a name can extend to the right of its dot without being
/// clipped at a map tile boundary (see `PortsOverlayRenderer`'s doc comment). Because an
/// `MKAnnotationView` *can* receive touches by default, `PortLabelAnnotationView` explicitly
/// disables that (`isEnabled = false`, `isUserInteractionEnabled = false`, `canShowCallout =
/// false`) to preserve the same non-interactivity guarantee for names as for dots.
final class PortsOverlay: NSObject, MKOverlay {

    let markers: [PortMarker]

    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect

    init(markers: [PortMarker]) {
        self.markers = markers

        if markers.isEmpty {
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            self.boundingMapRect = .null
        } else {
            var rect = MKMapRect.null
            for marker in markers {
                let point = MKMapPoint(marker.coordinate)
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
            }
            self.boundingMapRect = rect
            self.coordinate = MKMapPoint(x: rect.midX, y: rect.midY).coordinate
        }
    }
}
