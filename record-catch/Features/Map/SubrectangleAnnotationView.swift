import MapKit
import UIKit

/// Renders a subrectangle's code as a pill-shaped UILabel badge.
///
/// A `UILabel`-backed `MKAnnotationView` only lays out and draws when its content actually
/// changes (selection state) or when MapKit dequeues/positions it — much cheaper than drawing
/// thousands of independent text labels via CoreText inside an overlay renderer, and it keeps
/// text legible while zooming without creating "thousands of independent UIKit views" (labels are
/// hidden below `LabelVisibility.latitudeDeltaThreshold` instead of being removed/recreated).
final class SubrectangleAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "SubrectangleAnnotationView"

    private let label = UILabel()

    private static let horizontalPadding: CGFloat = 5
    private static let verticalPadding: CGFloat = 2

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureLabel()

        if let subrectangleAnnotation = annotation as? SubrectangleAnnotation {
            configure(subCode: subrectangleAnnotation.subCode, isSelected: false)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabel()
    }

    private func configureLabel() {
        // Ports remain the only interactive-looking marker layer to avoid, but subrectangle
        // labels are also display-only: selection happens via the map's tap gesture against the
        // polygon layer, not by tapping the label itself.
        canShowCallout = false

        // `.required` so a subrectangle code is never hidden by MapKit's collision handling — in
        // particular, it always wins over an overlapping port name (`PortLabelAnnotationView` is
        // `.defaultLow`), per the agreed label priority.
        collisionMode = .rectangle
        displayPriority = .required

        label.textAlignment = .center
        label.numberOfLines = 1
        label.layer.masksToBounds = true
        addSubview(label)
    }

    /// Applies the visual style for the current selection state and sizes the badge to fit its text.
    ///
    /// Unselected labels deliberately have **no solid background** — they render as coloured text
    /// with a white halo (the same technique `PortLabelAnnotationView` uses for port names) so a
    /// dense grid of subrectangle codes doesn't sit on top of, and obscure, port names underneath.
    /// Only the *selected* subrectangle gets a solid pill, so the current selection still reads
    /// clearly.
    func configure(subCode: String, isSelected: Bool) {
        let font = UIFont.systemFont(ofSize: isSelected ? 18 : 16, weight: isSelected ? .bold : .semibold)

        if isSelected {
            label.attributedText = nil
            label.text = subCode
            label.font = font
            label.textColor = .white
            label.backgroundColor = MapColorPalette.subrectangleSelected
        } else {
            label.text = nil
            label.backgroundColor = .clear
            label.attributedText = NSAttributedString(
                string: subCode,
                attributes: [
                    .font: font,
                    .foregroundColor: MapColorPalette.subrectangleGrid,
                    .strokeColor: UIColor.white,
                    // See `PortLabelAnnotationView.configure` — a negative stroke width both
                    // fills and strokes the glyphs in one pass, giving a halo that stays legible
                    // over both the sea and the dark landmass.
                    .strokeWidth: -3
                ]
            )
        }

        let textSize = label.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )

        let badgeSize = CGSize(
            width: textSize.width + Self.horizontalPadding * 2,
            height: textSize.height + Self.verticalPadding * 2
        )

        label.frame = CGRect(origin: .zero, size: badgeSize)
        label.layer.cornerRadius = isSelected ? 5 : 0

        bounds = CGRect(origin: .zero, size: badgeSize)
    }
}
