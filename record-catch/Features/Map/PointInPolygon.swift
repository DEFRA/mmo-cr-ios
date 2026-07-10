import CoreGraphics

/// A pure, MapKit-independent point-in-polygon test.
///
/// Kept separate from any MapKit types so it can be unit tested directly,
/// without needing to construct `MKPolygon`/`MKMapPoint` instances or run
/// on a simulator/device.
enum PointInPolygon {

    /// Returns true if `point` lies inside the polygon described by `ring`,
    /// using the standard even-odd ray casting algorithm.
    ///
    /// - `ring` does not need to be explicitly closed (first point repeated
    ///   at the end); both closed and open rings work.
    /// - Points exactly on an edge may return either `true` or `false` —
    ///   this is inherent to the ray casting algorithm and matches the
    ///   original implementation's behavior.
    static func contains(_ point: CGPoint, ring: [CGPoint]) -> Bool {
        guard ring.count > 2 else { return false }

        var isInside = false
        var previousIndex = ring.count - 1

        for currentIndex in 0..<ring.count {
            let current = ring[currentIndex]
            let previous = ring[previousIndex]

            let crossesRay = (current.y > point.y) != (previous.y > point.y)

            if crossesRay {
                let slopeIntersectX = (previous.x - current.x) * (point.y - current.y)
                    / (previous.y - current.y) + current.x

                if point.x < slopeIntersectX {
                    isInside.toggle()
                }
            }

            previousIndex = currentIndex
        }

        return isInside
    }
}
