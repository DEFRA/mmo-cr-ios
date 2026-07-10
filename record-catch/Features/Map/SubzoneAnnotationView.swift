import MapKit
import UIKit

/// Renders a subzone's code as a pill-shaped UILabel badge.
///
/// This replaces the previous approach of drawing the label with CoreText
/// inside `MKOverlayPathRenderer.draw(_:zoomScale:in:)`, which re-ran on
/// every overlay redraw (every frame during pan/zoom, for every visible
/// subzone). A `UILabel`-backed `MKAnnotationView` only lays out and draws
/// when its content actually changes (selection state) or when MapKit
/// dequeues/positions it, which is dramatically cheaper.
final class SubzoneAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "SubzoneAnnotationView"

    private let label = UILabel()

    private static let horizontalPadding: CGFloat = 7
    private static let verticalPadding: CGFloat = 4

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureLabel()

        if let subzoneAnnotation = annotation as? SubzoneAnnotation {
            configure(subCode: subzoneAnnotation.subCode, isSelected: false)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLabel()
    }

    private func configureLabel() {
        canShowCallout = false
        collisionMode = .none

        label.textAlignment = .center
        label.layer.masksToBounds = true
        addSubview(label)
    }

    /// Applies the visual style for the current selection state and sizes
    /// the badge to fit its text.
    func configure(subCode: String, isSelected: Bool) {
        label.text = subCode
        label.font = .systemFont(ofSize: isSelected ? 22 : 20, weight: isSelected ? .bold : .semibold)
        label.textColor = isSelected ? .white : .systemBlue
        label.backgroundColor = isSelected ? .systemRed : UIColor.white.withAlphaComponent(0.9)

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
