import Foundation

/// Errors that can occur while loading or parsing the bundled offline map GeoJSON resources.
///
/// A single malformed *feature* inside an otherwise valid GeoJSON file is never fatal — loaders
/// skip it and carry on (see `GeoJSONPropertiesDecoder`). These cases cover only failures that
/// mean an entire layer's resource can't be used at all.
enum OfflineMapDataError: Error, Equatable {
    /// The named GeoJSON resource could not be found in the given bundle.
    case resourceNotFound(String)
    /// The resource's contents are not valid JSON / GeoJSON.
    case invalidGeoJSON
}
