import MapKit

/// Lightweight annotation used solely to place a `SubzoneAnnotationView` (a
/// UILabel-based badge) at a subzone's centroid.
final class SubzoneAnnotation: NSObject, MKAnnotation {

    let subCode: String
    let coordinate: CLLocationCoordinate2D

    init(subCode: String, coordinate: CLLocationCoordinate2D) {
        self.subCode = subCode
        self.coordinate = coordinate
    }
}
