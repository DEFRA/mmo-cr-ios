import Foundation
import MapKit

/// Loads the precomputed `.plist` layers (see `PrecomputedMapData`) — the offline, build-time
/// equivalent of `MapLandLoader`/`SubrectangleLoader`/`PortLoader`, but with the GeoJSON parsing,
/// coordinate reprojection and sea-overlap sampling already done and baked into the resource, so
/// loading here is just decode + reconstruct.
enum PrecomputedMapLoader {

    /// Mirrors `SubrectangleLoader.Result`, plus the subset that's actually selectable (i.e.
    /// overlaps the sea) — already resolved at generation time, so `OfflineMapCoordinator` never
    /// re-runs `SubrectangleSeaOverlap`'s point-sampling.
    struct SubrectangleResult {
        let overlays: [SubrectangleOverlay]
        let selectableOverlays: [SubrectangleOverlay]
        let annotations: [SubrectangleAnnotation]
    }

    static func loadLand(from data: Data) throws -> [MapLandOverlay] {
        let layer = try PropertyListDecoder().decode(PrecomputedMapData.LandLayer.self, from: data)
        return layer.landPolygons.map { MapLandOverlay(multiPolygon: $0.multiPolygon) }
    }

    static func loadSubrectangles(from data: Data) throws -> SubrectangleResult {
        let layer = try PropertyListDecoder().decode(PrecomputedMapData.SubrectangleLayer.self, from: data)

        var overlays: [SubrectangleOverlay] = []
        var selectableOverlays: [SubrectangleOverlay] = []
        var annotations: [SubrectangleAnnotation] = []

        for subrectangle in layer.subrectangles {
            let overlay = SubrectangleOverlay(
                multiPolygon: subrectangle.multiPolygon.multiPolygon,
                properties: subrectangle.properties
            )
            overlays.append(overlay)

            if subrectangle.overlapsSea {
                selectableOverlays.append(overlay)
                annotations.append(SubrectangleAnnotation(
                    subCode: subrectangle.properties.subCode,
                    coordinate: subrectangle.labelCoordinate.coordinate
                ))
            }
        }

        return SubrectangleResult(overlays: overlays, selectableOverlays: selectableOverlays, annotations: annotations)
    }

    static func loadPorts(from data: Data) throws -> [PortMarker] {
        let layer = try PropertyListDecoder().decode(PrecomputedMapData.PortLayer.self, from: data)
        return layer.ports.map { PortMarker(portCode: $0.portCode, name: $0.name, coordinate: $0.coordinate.coordinate) }
    }

    // MARK: - Bundled resources

    static func loadBundledLand(bundle: Bundle = .main) throws -> [MapLandOverlay] {
        try loadLand(from: bundledData(resource: "map-precomputed", bundle: bundle))
    }

    static func loadBundledSubrectangles(bundle: Bundle = .main) throws -> SubrectangleResult {
        try loadSubrectangles(from: bundledData(resource: "subrectangles-precomputed", bundle: bundle))
    }

    static func loadBundledPorts(bundle: Bundle = .main) throws -> [PortMarker] {
        try loadPorts(from: bundledData(resource: "ports-precomputed", bundle: bundle))
    }

    private static func bundledData(resource: String, bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: resource, withExtension: "plist") else {
            throw OfflineMapDataError.resourceNotFound(resource)
        }
        return try Data(contentsOf: url)
    }
}
