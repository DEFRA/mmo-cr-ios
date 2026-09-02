import Foundation
import MapKit

/// Loads and parses the ports layer ("ports.geojson" — port locations, display-only).
///
/// Takes raw `Data` rather than a bundle/file URL so it can be unit tested with inline sample
/// GeoJSON.
enum PortLoader {

    /// Raw `ports.geojson` properties. `lat`/`long_` duplicate the geometry's coordinate in the
    /// source data; they're decoded as a fallback for the (unexpected) case where the geometry
    /// itself is missing or invalid, but the geometry-derived coordinate is preferred.
    private struct PortProperties: Decodable {
        let port: String
        let portCode: Double
        let lat: Double?
        let long: Double?

        enum CodingKeys: String, CodingKey {
            case port
            case portCode = "port_code"
            case lat
            case long = "long_"
        }
    }

    static func load(from data: Data) throws -> [PortMarker] {
        let features = try RawGeoJSON.features(from: data)

        var markers: [PortMarker] = []

        for feature in features {
            guard let properties = GeoJSONPropertiesDecoder.decode(PortProperties.self, from: feature.propertiesData) else {
                continue
            }

            guard let coordinate = coordinate(for: feature, properties: properties) else { continue }

            markers.append(PortMarker(portCode: properties.portCode, name: properties.port, coordinate: coordinate))
        }

        return markers
    }

    /// Loads and parses the bundled "ports.geojson" resource.
    static func loadBundled(bundle: Bundle = .main) throws -> [PortMarker] {
        let data = try GeoJSONBundleLoader.loadData(resource: "ports", bundle: bundle)
        return try load(from: data)
    }

    private static func coordinate(for feature: RawGeoJSON.Feature, properties: PortProperties) -> CLLocationCoordinate2D? {
        if let geometryCoordinate = RawGeoJSONGeometry.coordinates(
            fromFeatureGeometryType: feature.geometryType,
            coordinates: feature.coordinates
        ).first {
            return geometryCoordinate
        }

        guard let lat = properties.lat, let long = properties.long else { return nil }
        let fallback = CLLocationCoordinate2D(latitude: lat, longitude: long)
        return CLLocationCoordinate2DIsValid(fallback) ? fallback : nil
    }
}
