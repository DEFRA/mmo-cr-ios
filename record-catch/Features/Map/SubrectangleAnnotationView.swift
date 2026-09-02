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

    private static let horizontalPadding: CGFloat = 7
    private static let verticalPadding: CGFloat = 4

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
        collisionMode = .none

        label.textAlignment = .center
        label.layer.masksToBounds = true
        addSubview(label)
    }

    /// Applies the visual style for the current selection state and sizes the badge to fit its text.
    func configure(subCode: String, isSelected: Bool) {
        label.text = subCode
        label.font = .systemFont(ofSize: isSelected ? 22 : 20, weight: isSelected ? .bold : .semibold)
        label.textColor = isSelected ? .white : MapColorPalette.subrectangleGrid
        label.backgroundColor = isSelected
            ? MapColorPalette.subrectangleSelected
            : UIColor.white.withAlphaComponent(0.9)

        let textSize = label.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )

        let badgeSize = CGSize(
            width: textSize.width + Self.horizontalPadding * 2,
            height: textSize.height + Self.verticalPadding * 2
        )

        label.frame = CGRect(origin: .zero, size: badgeSize)
        label.layer.cornerRadius = 6

        bounds = CGRect(origin: .zero, size: badgeSize)
    }
}
