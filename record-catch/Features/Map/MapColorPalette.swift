import UIKit

/// Centralises the offline fisheries map's colour scheme so every layer's renderer draws with the
/// same palette instead of scattering hex literals across renderer files.
///
/// Colours are deliberately **not** routed through `Core/DesignSystem` — this component is
/// app-agnostic/reusable map styling (see `OfflineMapView`'s doc comment), independent of the
/// app's semantic UI colours.
enum MapColorPalette {

    /// The sea/background behind every layer. White, per the map's colour scheme.
    static let sea = UIColor.white

    /// Main map (land) layer: solid fill.
    static let land = UIColor(hex: 0x0B4143)

    /// Main map (land) layer: thin outline.
    static let landOutline = UIColor.black

    /// Subrectangle grid boundaries (unselected).
    static let subrectangleGrid = UIColor(hex: 0x0B6B3A)

    /// Selected subrectangle fill/stroke — a warm amber rather than an alarm-red, so it reads as
    /// "chosen" without the harsher, error-like connotation of red against the teal/dark-green
    /// scheme, while still remaining clearly distinct in both fill and (thicker) stroke width from
    /// the unselected state.
    static let subrectangleSelected = UIColor(hex: 0xE8A63A)

    /// Port markers.
    static let port = UIColor(hex: 0x01FEE2)

    /// Port marker outline, for contrast against both the light sea and dark land fills.
    static let portOutline = UIColor.black

    /// Border drawn around the whole map view (see `OfflineMapView.makeUIView`).
    static let mapBorder = UIColor.black
}

private extension UIColor {
    /// Convenience initialiser for the palette's `0xRRGGBB` literals above.
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
