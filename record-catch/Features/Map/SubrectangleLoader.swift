import Foundation
import MapKit

/// Loads and parses the subrectangle layer ("subrectangles.geojson" — boundaries + labels).
///
/// Takes raw `Data` rather than a bundle/file URL so it can be unit tested with inline sample
/// GeoJSON.
enum SubrectangleLoader {

    struct Result {
        let overlays: [SubrectangleOverlay]
        let annotations: [SubrectangleAnnotation]
    }

    static func load(from data: Data) throws -> Result {
        let features = try RawGeoJSON.features(from: data)

        var overlays: [SubrectangleOverlay] = []
        var annotations: [SubrectangleAnnotation] = []

        for feature in features {
            // A feature whose properties don't decode (missing/mistyped `sub_code`, etc.) can't
            // be identified if selected, so it's skipped entirely rather than failing the load.
            guard let properties = GeoJSONPropertiesDecoder.decode(SubrectangleProperties.self, from: feature.propertiesData) else {
                continue
            }

            // A feature whose geometry is missing/unsupported, or whose coordinates are entirely
            // invalid (e.g. the stray non-WGS84 value present in the real dataset), is skipped on
            // its own — it never fails the rest of the load (see `RawGeoJSON`'s doc comment).
            guard let multiPolygon = RawGeoJSONGeometry.multiPolygon(
                fromFeatureGeometryType: feature.geometryType,
                coordinates: feature.coordinates
            ) else {
                continue
            }

            let overlay = SubrectangleOverlay(multiPolygon: multiPolygon, properties: properties)
            overlays.append(overlay)
            annotations.append(SubrectangleAnnotation(subCode: properties.subCode, coordinate: overlay.labelCoordinate))
        }

        return Result(overlays: overlays, annotations: annotations)
    }

    /// Loads and parses the bundled "subrectangles.geojson" resource.
    static func loadBundled(bundle: Bundle = .main) throws -> Result {
        let data = try GeoJSONBundleLoader.loadData(resource: "subrectangles", bundle: bundle)
        return try load(from: data)
    }
}
