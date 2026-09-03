import MapKit
import UIKit

/// Draws every port as a small, clearly visible, non-interactive marker dot.
///
/// Culls markers outside the tile's `mapRect` so drawing cost scales with what's on screen, not
/// with the total port count.
///
/// Port **names** are drawn separately, by `PortLabelAnnotationView` — not here. An earlier
/// version of this renderer also drew names directly into the tile's `CGContext`, but
/// `MKOverlayRenderer.draw` is clipped to the tile it's called for: a name whose text crossed a
/// tile seam was silently cut short, and because culling keyed on the marker's *point* (not its
/// label's extent), the neighbouring tile the text spilled into never redrew it either. Moving
/// names to `MKAnnotationView`s (mirroring how subrectangle codes are already drawn) fixes that,
/// without giving up this overlay's non-interactivity guarantee for the dots themselves — see
/// `PortsOverlay`'s doc comment.
final class PortsOverlayRenderer: MKOverlayRenderer {

    private let portsOverlay: PortsOverlay

    private static let markerRadius: CGFloat = 5

    init(overlay: PortsOverlay) {
        self.portsOverlay = overlay
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let radius = Self.markerRadius / zoomScale

        context.setFillColor(MapColorPalette.port.cgColor)
        context.setStrokeColor(MapColorPalette.portOutline.cgColor)
        context.setLineWidth(1 / zoomScale)

        for marker in portsOverlay.markers {
            let mapPoint = MKMapPoint(marker.coordinate)
            guard mapRect.contains(mapPoint) else { continue }

            let center = point(for: mapPoint)
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.addEllipse(in: rect)
            context.drawPath(using: .fillStroke)
        }
    }
}
