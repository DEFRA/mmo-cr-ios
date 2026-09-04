import CoreGraphics
import MapKit

/// A single selectable subrectangle, drawn as an `MKOverlay`.
final class SubrectangleOverlay: NSObject, MKOverlay {

    let multiPolygon: MKMultiPolygon
    let properties: SubrectangleProperties

    var subCode: String { properties.subCode }

    var coordinate: CLLocationCoordinate2D { multiPolygon.coordinate }
    var boundingMapRect: MKMapRect { multiPolygon.boundingMapRect }

    /// Coordinate used for placing the subrectangle's text label: the polygon's own bounding-rect
    /// centre.
    ///
    /// Deliberately does **not** use the source data's `stat_x`/`stat_y` properties: in the real
    /// bundled dataset those are the centre of the *parent ICES rectangle* (e.g. `"27D8"`), not
    /// the individual subrectangle (e.g. `"27D86"`) — every subrectangle sharing that parent
    /// carries the *same* `stat_x`/`stat_y` value. Using them here collapsed every subrectangle
    /// within a parent rectangle onto a single label point, so only one of every ~6–9 sibling
    /// subrectangles ever showed a visible label. The bounding-rect centre is always specific to
    /// this subrectangle's own geometry, so it can never collide with a sibling's label point.
    var labelCoordinate: CLLocationCoordinate2D {
        MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }

    init(multiPolygon: MKMultiPolygon, properties: SubrectangleProperties) {
        self.multiPolygon = multiPolygon
        self.properties = properties
    }

    /// Returns true if `mapPoint` falls inside this subrectangle (accounting for any holes).
    func contains(_ mapPoint: MKMapPoint) -> Bool {
        multiPolygon.polygons.contains { $0.containsSubrectanglePoint(mapPoint) }
    }
}

extension MKPolygon {

    /// Exterior-with-holes containment test, built on the pure `PointInPolygon` algorithm.
    func containsSubrectanglePoint(_ mapPoint: MKMapPoint) -> Bool {
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
