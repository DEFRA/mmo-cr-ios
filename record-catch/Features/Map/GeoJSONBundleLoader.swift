import Foundation

/// Loads raw GeoJSON `Data` for a named bundled resource.
///
/// Kept separate from parsing so each layer's loader can be unit tested against inline sample
/// GeoJSON without touching the app bundle, and so "resource missing" is a single, consistently
/// reported error across all three layers.
enum GeoJSONBundleLoader {
    static func loadData(resource: String, withExtension fileExtension: String = "geojson", bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: resource, withExtension: fileExtension) else {
            throw OfflineMapDataError.resourceNotFound(resource)
        }

        return try Data(contentsOf: url)
    }
}
