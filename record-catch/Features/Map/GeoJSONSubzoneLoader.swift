import Foundation
import MapKit

enum GeoJSONSubzoneLoaderError: Error, Equatable {
    case resourceNotFound
}

enum GeoJSONSubzoneLoader {

    struct Result {
        let overlays: [SubzoneOverlay]
        let annotations: [SubzoneAnnotation]
    }

    /// Parses subzone GeoJSON data into overlays (for drawing) and
    /// annotations (for UILabel-based badges).
    ///
    /// Takes raw `Data` rather than a bundle/file URL so it can be unit
    /// tested with inline sample GeoJSON.
    static func load(from data: Data) throws -> Result {
        let objects = try MKGeoJSONDecoder().decode(data)

        var overlays: [SubzoneOverlay] = []
        var annotations: [SubzoneAnnotation] = []

        for object in objects {
            guard let feature = object as? MKGeoJSONFeature else { continue }

            let subCode = SubzoneCodeDecoder.decode(from: feature.properties)

            for geometry in feature.geometry {
                guard let multiPolygon = multiPolygon(from: geometry) else { continue }

                let overlay = SubzoneOverlay(multiPolygon: multiPolygon, subCode: subCode)
                overlays.append(overlay)
                annotations.append(SubzoneAnnotation(subCode: subCode, coordinate: overlay.labelCoordinate))
            }
        }

        return Result(overlays: overlays, annotations: annotations)
    }

    /// Loads and parses the bundled "subzones.geojson" resource.
    static func loadBundledSubzones(bundle: Bundle = .main) throws -> Result {
        guard let url = bundle.url(forResource: "subzones", withExtension: "geojson") else {
            throw GeoJSONSubzoneLoaderError.resourceNotFound
        }

        let data = try Data(contentsOf: url)
        return try load(from: data)
    }

    private static func multiPolygon(from geometry: MKShape) -> MKMultiPolygon? {
        if let multiPolygon = geometry as? MKMultiPolygon {
            return multiPolygon
        }

        if let polygon = geometry as? MKPolygon {
            return MKMultiPolygon([polygon])
        }

        return nil
    }
}
