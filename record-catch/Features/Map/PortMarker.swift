import CoreLocation
import Foundation

/// A single display-only port location, preserved from a `ports.geojson` feature.
///
/// Deliberately not `MKAnnotation`/`MKOverlay` itself — ports are rendered in a single
/// `PortsOverlay` (dots) plus one `PortLabelAnnotation` per port (its name; see those types' doc
/// comments), so this is a plain, MapKit-independent value that's easy to unit test.
struct PortMarker: Equatable {

    /// `port_code` — numeric port identifier.
    let portCode: Double
    /// `port` — display name.
    let name: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: PortMarker, rhs: PortMarker) -> Bool {
        lhs.portCode == rhs.portCode
            && lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
