import MapKit

/// Draws a subzone's fill and stroke.
///
/// Text labels are now handled separately by `SubzoneAnnotationView`, so
/// this renderer only needs `setNeedsDisplay()` when its own selection
/// state actually changes — not on every frame, and not for every other
/// subzone on screen.
final class SubzoneOverlayRenderer: MKOverlayPathRenderer {

    private let subzoneOverlay: SubzoneOverlay

    var isSelected: Bool = false {
        didSet {
            guard isSelected != oldValue else { return }
            setNeedsDisplay()
        }
    }

    init(overlay: SubzoneOverlay) {
        self.subzoneOverlay = overlay
        super.init(overlay: overlay)
    }

    override func createPath() {
        let path = CGMutablePath()

        for polygon in subzoneOverlay.multiPolygon.polygons {
            addPolygon(polygon, to: path)
        }

        self.path = path
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if path == nil {
            createPath()
        }

        guard let path else { return }

        context.addPath(path)

        context.setFillColor(
            isSelected
                ? UIColor.systemRed.withAlphaComponent(0.35).cgColor
                : UIColor.systemBlue.withAlphaComponent(0.12).cgColor
        )

        context.setStrokeColor(
            isSelected ? UIColor.systemRed.cgColor : UIColor.systemBlue.cgColor
        )

        context.setLineWidth((isSelected ? 3 : 1) / zoomScale)

        context.drawPath(using: .eoFillStroke)
    }

    private func addPolygon(_ polygon: MKPolygon, to path: CGMutablePath) {
        addRing(points: polygon.points(), count: polygon.pointCount, to: path)

        polygon.interiorPolygons?.forEach { interiorPolygon in
            addRing(points: interiorPolygon.points(), count: interiorPolygon.pointCount, to: path)
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
