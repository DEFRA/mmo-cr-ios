import MapKit

/// Draws the main map's land polygons: a solid fill with a thin, clearly visible outline,
/// suitable as a background layer that the subrectangle and port layers are drawn on top of.
final class MapLandOverlayRenderer: MKOverlayPathRenderer {

    private let landOverlay: MapLandOverlay

    init(overlay: MapLandOverlay) {
        self.landOverlay = overlay
        super.init(overlay: overlay)
    }

    override func createPath() {
        let path = CGMutablePath()
        addRings(of: landOverlay.multiPolygon, to: path)
        self.path = path
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if path == nil {
            createPath()
        }

        guard let path else { return }

        context.addPath(path)
        context.setFillColor(MapColorPalette.land.cgColor)
        context.setStrokeColor(MapColorPalette.landOutline.cgColor)
        context.setLineWidth(1 / zoomScale)
        context.drawPath(using: .eoFillStroke)
    }
}
