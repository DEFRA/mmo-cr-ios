import MapKit

/// Shared path-building for `MKOverlayPathRenderer` subclasses that draw filled/stroked
/// multi-polygons (the main map's land layer and the subrectangle layer).
///
/// Extracted so the two renderers don't duplicate the same ring-walking code.
extension MKOverlayPathRenderer {

    /// Adds every ring (exterior + any holes) of every polygon in `multiPolygon` to `path`,
    /// converting each map point via `point(for:)`.
    func addRings(of multiPolygon: MKMultiPolygon, to path: CGMutablePath) {
        for polygon in multiPolygon.polygons {
            addRing(points: polygon.points(), count: polygon.pointCount, to: path)

            polygon.interiorPolygons?.forEach { interiorPolygon in
                addRing(points: interiorPolygon.points(), count: interiorPolygon.pointCount, to: path)
            }
        }
    }

    private func addRing(points: UnsafeMutablePointer<MKMapPoint>, count: Int, to path: CGMutablePath) {
        guard count > 0 else { return }

        path.move(to: point(for: points[0]))

        for index in 1..<count {
            path.addLine(to: point(for: points[index]))
        }

        path.closeSubpath()
    }
}
