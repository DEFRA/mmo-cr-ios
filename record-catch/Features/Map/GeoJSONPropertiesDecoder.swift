import Foundation

/// Decodes a GeoJSON feature's raw `properties` payload into a typed model.
///
/// Centralises the "missing/malformed properties should not crash parsing" behaviour used by
/// every layer loader: a `nil` result means the caller should skip that single feature rather
/// than fail the whole load (see the individual loaders' `load(from:)`).
///
/// `nonisolated` — pure decoding with no UI/mutable state — for the same reason as `RawGeoJSON`.
nonisolated enum GeoJSONPropertiesDecoder {
    static func decode<T: Decodable>(_ type: T.Type, from propertiesData: Data?) -> T? {
        guard let propertiesData else { return nil }
        return try? JSONDecoder().decode(type, from: propertiesData)
    }
}
