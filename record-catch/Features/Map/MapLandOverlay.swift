import MapKit

/// A single main-map land polygon feature (background layer). Not selectable.
final class MapLandOverlay: NSObject, MKOverlay {

    let multiPolygon: MKMultiPolygon

    var coordinate: CLLocationCoordinate2D { multiPolygon.coordinate }
    var boundingMapRect: MKMapRect { multiPolygon.boundingMapRect }

    init(multiPolygon: MKMultiPolygon) {
        self.multiPolygon = multiPolygon
    }
}
