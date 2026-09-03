import MapKit

/// Lightweight annotation used solely to place a `PortLabelAnnotationView` (a non-interactive
/// text badge) at a port's coordinate.
///
/// Mirrors `SubrectangleAnnotation`. Ports themselves are drawn as small dots by
/// `PortsOverlay`/`PortsOverlayRenderer` — this annotation carries only what's needed to draw the
/// port's **name** as a real `UILabel`-backed view instead of glyphs drawn into a map tile's
/// `CGContext`. Drawing text into a tile context clips at the tile boundary, which is what
/// previously caused port names to be cut short when they crossed a tile seam; an annotation view
/// isn't tile-clipped, so this is the fix for that bug (see `PortsOverlayRenderer`'s doc comment).
final class PortLabelAnnotation: NSObject, MKAnnotation {

    /// `port_code` — numeric port identifier, used to key reuse/lookup dictionaries.
    let portCode: Double
    let name: String
    let coordinate: CLLocationCoordinate2D

    init(portCode: Double, name: String, coordinate: CLLocationCoordinate2D) {
        self.portCode = portCode
        self.name = name
        self.coordinate = coordinate
    }

    /// Builds one annotation per marker, preserving order. Pure/side-effect-free so it's easy to
    /// unit test independently of any live `MKMapView`.
    static func annotations(for markers: [PortMarker]) -> [PortLabelAnnotation] {
        markers.map { PortLabelAnnotation(portCode: $0.portCode, name: $0.name, coordinate: $0.coordinate) }
    }
}
