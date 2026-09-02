import MapKit
import UIKit

/// Draws every port as a small, clearly visible, non-interactive marker dot, with its name drawn
/// alongside once zoomed in past `LabelVisibility.latitudeDeltaThreshold`.
///
/// Culls markers outside the tile's `mapRect` so drawing cost scales with what's on screen, not
/// with the total port count. Names are drawn directly into the tile's `CGContext` — a `UILabel`-
/// backed `MKAnnotationView` per port (as used for subrectangles) was deliberately avoided here:
/// ports are drawn as a single `MKOverlay` specifically so they can never be interactive (see
/// `PortsOverlay`'s doc comment), and ~900 additional per-port views would undo that.
final class PortsOverlayRenderer: MKOverlayRenderer {

    private let portsOverlay: PortsOverlay

    /// Whether port names should be drawn this frame. Toggled by `OfflineMapCoordinator` as the
    /// visible region crosses `LabelVisibility.latitudeDeltaThreshold` — mirrors how subrectangle
    /// labels are shown/hidden, so both layers change together. Only triggers a redraw when the
    /// value actually changes.
    var showsLabels: Bool = false {
        didSet {
            guard showsLabels != oldValue else { return }
            setNeedsDisplay()
        }
    }

    private static let markerRadius: CGFloat = 5
    private static let labelFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    private static let labelOffset: CGFloat = 9

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

            if showsLabels {
                drawLabel(marker.name, nextTo: center, zoomScale: zoomScale, in: context)
            }
        }
    }

    /// Draws `text` to the right of `center`, scaled so it stays a constant on-screen size
    /// regardless of zoom (matching the marker dot and stroke widths above).
    ///
    /// This draws real Core Text glyph outlines (via `NSString.draw`), not a rasterised bitmap —
    /// it stays crisp/"vector" at any zoom level. `MKOverlayRenderer`'s context already uses the
    /// same orientation as `point(for:)` (i.e. no extra Y-flip is needed here, unlike some other
    /// MapKit/CoreText drawing recipes — an earlier version of this method added one and drew
    /// every port name upside down as a result). Only a uniform `1/zoomScale` scale is applied, so
    /// the text keeps a constant on-screen size as the map is zoomed.
    private func drawLabel(_ text: String, nextTo center: CGPoint, zoomScale: MKZoomScale, in context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.labelFont,
            .foregroundColor: UIColor.black,
            .strokeColor: UIColor.white,
            // Negative width draws both a stroke (halo, for legibility over any background) and a
            // fill in one pass. The magnitude is a percentage of the font's point size: -3
            // rendered a sub-half-point halo — effectively invisible against the dark land fill —
            // while -14 (~1.8pt) swallowed the glyph fill entirely at the previous, smaller 13pt
            // font size. Now that the font itself is a more readable 16pt, -7 (~1.1pt) gives a
            // halo that reads clearly over both the sea and the landmass without eating the fill.
            .strokeWidth: -3
        ]

        let size = (text as NSString).size(withAttributes: attributes)
        let scale = 1 / zoomScale

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: scale, y: scale)

        UIGraphicsPushContext(context)
        (text as NSString).draw(
            at: CGPoint(x: Self.labelOffset, y: -size.height / 2),
            withAttributes: attributes
        )
        UIGraphicsPopContext()

        context.restoreGState()
    }
}
