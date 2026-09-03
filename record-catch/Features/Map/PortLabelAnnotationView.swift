import MapKit
import UIKit

/// Renders a port's name as a non-interactive text badge, positioned to the right of the port's
/// dot (drawn separately by `PortsOverlayRenderer`).
///
/// Replaces drawing port names directly into a map tile's `CGContext`: `MKOverlayRenderer.draw`
/// clips to the tile it's called for, so a name whose text crossed a tile seam was silently cut
/// short, and — because the previous renderer culled by the marker's point, not its label's extent
/// — the neighbouring tile the text spilled into never redrew it either. A `UILabel`-backed
/// `MKAnnotationView` is never tile-clipped and only lays out when its content actually changes or
/// MapKit repositions it (the same reasoning `SubrectangleAnnotationView` documents), so this is
/// both the fix and no more expensive than the grid of subrectangle badges already on screen.
///
/// Deliberately configured so a port can never be selected or show a callout — see
/// `PortsOverlay`'s doc comment for why that guarantee must hold regardless of how names are
/// drawn.
final class PortLabelAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "PortLabelAnnotationView"

    private let label = UILabel()

    /// Matches `PortsOverlayRenderer`'s previous `labelOffset` — the gap between the port's dot
    /// and the start of its name.
    private static let labelOffset: CGFloat = 9
    private static let font = UIFont.systemFont(ofSize: 18, weight: .semibold)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureView()

        if let portLabelAnnotation = annotation as? PortLabelAnnotation {
            configure(name: portLabelAnnotation.name)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        // Ports must never be selectable and never show a callout (see `PortsOverlay`'s doc
        // comment) — unlike an `MKOverlay`, an `MKAnnotationView` *can* receive touches by
        // default, so this has to be turned off explicitly rather than relied on structurally.
        canShowCallout = false
        isEnabled = false
        isUserInteractionEnabled = false

        // Cheap collision avoidance: let MapKit hide overlapping port names for us instead of
        // hand-rolling occupied-rect tracking. `.defaultLow` so subrectangle codes
        // (`SubrectangleAnnotationView`, `.required`) always win when the two would overlap.
        collisionMode = .rectangle
        displayPriority = .defaultLow

        label.numberOfLines = 1
        addSubview(label)
    }

    /// Sizes and positions the badge for `name`, to the right of and vertically centred on the
    /// annotation's coordinate (the port's dot).
    func configure(name: String) {
        label.attributedText = NSAttributedString(
            string: name,
            attributes: [
                .font: Self.font,
                .foregroundColor: UIColor.black,
                .strokeColor: UIColor.white,
                // See the previous `PortsOverlayRenderer.drawLabel` — a halo (drawn via a negative
                // stroke width, which fills *and* strokes in one pass) keeps the name legible over
                // both the light sea and the dark landmass.
                .strokeWidth: -3
            ]
        )

        let textSize = label.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )

        label.frame = CGRect(origin: .zero, size: textSize)
        bounds = CGRect(origin: .zero, size: textSize)

        // Shifts the view so its left edge sits `labelOffset` to the right of the port coordinate,
        // while staying vertically centred on it — matching the previous CoreText-drawn layout.
        centerOffset = CGPoint(x: textSize.width / 2 + Self.labelOffset, y: 0)
    }
}
