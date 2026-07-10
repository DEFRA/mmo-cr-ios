import CoreGraphics
import MapKit

/// A single selectable sea subzone, drawn as an `MKOverlay`.
final class SubzoneOverlay: NSObject, MKOverlay {

    let multiPolygon: MKMultiPolygon
    let subCode: String

    var coordinate: CLLocationCoordinate2D {
        multiPolygon.coordinate
    }

    var boundingMapRect: MKMapRect {
        multiPolygon.boundingMapRect
    }

    /// Centroid used for placing the subzone's text label.
    var labelCoordinate: CLLocationCoordinate2D {
        MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }

    init(multiPolygon: MKMultiPolygon, subCode: String) {
        self.multiPolygon = multiPolygon
        self.subCode = subCode
    }

    /// Returns true if `mapPoint` falls inside this subzone (accounting for any holes).
    func contains(_ mapPoint: MKMapPoint) -> Bool {
        multiPolygon.polygons.contains { $0.containsSubzonePoint(mapPoint) }
    }
}

extension MKPolygon {

    /// Exterior-with-holes containment test, built on the pure `PointInPolygon` algorithm.
    func containsSubzonePoint(_ mapPoint: MKMapPoint) -> Bool {
        guard containsInExterior(mapPoint) else {
            return false
        }

        if let interiorPolygons {
            for interiorPolygon in interiorPolygons where interiorPolygon.containsInExterior(mapPoint) {
                return false
            }
        }

        return true
    }

    func containsInExterior(_ mapPoint: MKMapPoint) -> Bool {
        guard pointCount > 0 else { return false }

        let mapPoints = points()
        let ring = (0..<pointCount).map { CGPoint(x: mapPoints[$0].x, y: mapPoints[$0].y) }

        return PointInPolygon.contains(CGPoint(x: mapPoint.x, y: mapPoint.y), ring: ring)
    }
}
