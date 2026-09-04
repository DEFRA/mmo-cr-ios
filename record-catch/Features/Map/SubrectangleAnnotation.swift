import MapKit

/// Lightweight annotation used solely to place a `SubrectangleAnnotationView` (a UILabel-based
/// badge) at a subrectangle's label coordinate.
final class SubrectangleAnnotation: NSObject, MKAnnotation {

    let subCode: String
    let coordinate: CLLocationCoordinate2D

    init(subCode: String, coordinate: CLLocationCoordinate2D) {
        self.subCode = subCode
        self.coordinate = coordinate
    }
}
