import MapKit

/// Draws a subrectangle's fill and stroke.
///
/// Fill is minimal/transparent so the underlying map remains visible; the selected subrectangle
/// gets a visibly different fill/stroke/line-width. Only `isSelected` triggers `setNeedsDisplay()`
/// — not every frame, and not for every other subrectangle on screen.
final class SubrectangleOverlayRenderer: MKOverlayPathRenderer {

    private let subrectangleOverlay: SubrectangleOverlay

    var isSelected: Bool = false {
        didSet {
            guard isSelected != oldValue else { return }
            setNeedsDisplay()
        }
    }

    init(overlay: SubrectangleOverlay) {
        self.subrectangleOverlay = overlay
        super.init(overlay: overlay)
    }

    override func createPath() {
        let path = CGMutablePath()
        addRings(of: subrectangleOverlay.multiPolygon, to: path)
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
                ? MapColorPalette.subrectangleSelected.withAlphaComponent(0.35).cgColor
                : MapColorPalette.subrectangleGrid.withAlphaComponent(0.06).cgColor
        )

        context.setStrokeColor(
            isSelected ? MapColorPalette.subrectangleSelected.cgColor : MapColorPalette.subrectangleGrid.cgColor
        )

        context.setLineWidth((isSelected ? 3 : 1) / zoomScale)

        context.drawPath(using: .eoFillStroke)
    }
}
