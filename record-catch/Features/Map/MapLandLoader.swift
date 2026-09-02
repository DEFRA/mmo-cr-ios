import Foundation
import MapKit

/// Loads and parses the main map layer ("map.geojson" — land polygons).
///
/// Takes raw `Data` rather than a bundle/file URL so it can be unit tested with inline sample
/// GeoJSON. This layer is background-only: it carries no selectable identity, so unlike the
/// subrectangle layer there is no properties model to preserve.
enum MapLandLoader {

    static func load(from data: Data) throws -> [MapLandOverlay] {
        let features = try RawGeoJSON.features(from: data)

        return features.compactMap { feature in
            RawGeoJSONGeometry.multiPolygon(
                fromFeatureGeometryType: feature.geometryType,
                coordinates: feature.coordinates
            ).map(MapLandOverlay.init)
        }
    }

    /// Loads and parses the bundled "map.geojson" resource.
    static func loadBundled(bundle: Bundle = .main) throws -> [MapLandOverlay] {
        let data = try GeoJSONBundleLoader.loadData(resource: "map", bundle: bundle)
        return try load(from: data)
    }
}
