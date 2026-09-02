import MapKit
import UIKit

/// A minimal, fully offline base-map tile overlay.
///
/// Synthesises a single solid-colour tile image **in memory** for every tile request — it never
/// performs a network request (no `URLSession`, no remote `url(forTilePath:)`), and setting
/// `canReplaceMapContent = true` tells MapKit to skip fetching Apple's own base-map tiles
/// entirely. This is what guarantees the map works with no connectivity: there is nothing
/// underneath the app's own GeoJSON-derived layers that could ever need the network.
final class BlankOfflineTileOverlay: MKTileOverlay {

    /// The sea backdrop. The land, subrectangle and port layers are drawn on top of this by their
    /// own renderers.
    private static let backgroundColor = MapColorPalette.sea

    private static let tileImageData: Data = {
        let size = CGSize(width: 1, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }()

    init() {
        // `urlTemplate: nil` — there is deliberately no remote tile source at all.
        super.init(urlTemplate: nil)
        canReplaceMapContent = true
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        // Synchronous, in-memory only — never touches the network.
        result(Self.tileImageData, nil)
    }
}
