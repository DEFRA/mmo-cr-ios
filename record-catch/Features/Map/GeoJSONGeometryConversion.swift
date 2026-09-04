import Foundation
import MapKit

/// A minimal, resilient GeoJSON reader built directly on `JSONSerialization` instead of
/// `MKGeoJSONDecoder`.
///
/// `MKGeoJSONDecoder.decode(_:)` is all-or-nothing: if **any single coordinate** anywhere in the
/// file is out of range, it throws for the **entire file** — there is no way to recover the other,
/// perfectly valid features. The real bundled `subrectangles.geojson` contains at least one such
/// coordinate (a stray non-WGS84 value), so relying on `MKGeoJSONDecoder` would silently fail to
/// render the *entire* subrectangle layer in production because of a single bad feature.
///
/// `RawGeoJSON` instead walks the JSON structure itself, validating coordinates as it goes, so a
/// malformed ring/feature can be skipped individually while every other feature still loads —
/// satisfying the "don't crash the whole layer over one optional feature" requirement in practice,
/// not just in principle.
///
/// `nonisolated` — pure parsing with no UI/mutable state — so callers outside MainActor code (e.g.
/// `BundledPortSearchProvider`) can use it too.
nonisolated enum RawGeoJSON {

    /// One `Feature` from a `FeatureCollection`, with its properties re-serialised back to `Data`
    /// (so `GeoJSONPropertiesDecoder`/`Decodable` property models are unaffected by this change)
    /// and its geometry kept as loosely-typed JSON for `RawGeoJSONGeometry` to validate.
    struct Feature {
        let propertiesData: Data?
        let geometryType: String?
        let coordinates: Any?
    }

    /// Parses a GeoJSON `FeatureCollection`'s top-level structure and each feature's `properties`/
    /// `geometry`. Throws only if the payload isn't valid JSON, or isn't a `FeatureCollection` with
    /// a `features` array at all — never for an individual feature's contents.
    static func features(from data: Data) throws -> [Feature] {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw OfflineMapDataError.invalidGeoJSON
        }

        guard let object = json as? [String: Any], let rawFeatures = object["features"] as? [Any] else {
            throw OfflineMapDataError.invalidGeoJSON
        }

        return rawFeatures.compactMap { rawFeature -> Feature? in
            guard let featureDict = rawFeature as? [String: Any] else { return nil }

            let propertiesData = (featureDict["properties"] as? [String: Any]).flatMap {
                try? JSONSerialization.data(withJSONObject: $0)
            }

            // `"geometry": null` is valid GeoJSON for an unlocated feature.
            guard let geometry = featureDict["geometry"] as? [String: Any] else {
                return Feature(propertiesData: propertiesData, geometryType: nil, coordinates: nil)
            }

            return Feature(
                propertiesData: propertiesData,
                geometryType: geometry["type"] as? String,
                coordinates: geometry["coordinates"]
            )
        }
    }
}

/// Validates and converts raw JSON coordinate structures into MapKit shapes.
///
/// Every function here is defensive: malformed input (wrong shape, non-numeric values, or a
/// coordinate that fails `CLLocationCoordinate2DIsValid`) returns `nil` rather than throwing, so
/// callers can skip just the offending ring/geometry/feature.
///
/// `nonisolated` for the same reason as `RawGeoJSON` above.
nonisolated enum RawGeoJSONGeometry {

    /// Parses a single `[longitude, latitude]` pair. GeoJSON orders coordinates as
    /// longitude-then-latitude — this is the one place that ordering is applied.
    ///
    /// Coordinate values are normally JSON numbers, but the real bundled `subrectangles.geojson`
    /// encodes at least some of them as numeric **strings** (e.g. `"-11.5"`) — `numericValue(_:)`
    /// accepts either, matching how lenient real-world GIS exports actually behave.
    ///
    /// **Known data anomaly:** every ring vertex in the real bundled `subrectangles.geojson` is
    /// actually encoded in **Web Mercator (EPSG:3857) metres**, not WGS84 degrees, even though the
    /// same features' own `stat_x`/`stat_y` properties *are* correct WGS84 degrees (confirmed by
    /// inverse-projecting a sample vertex and landing on that feature's own `stat_x`/`stat_y`). If
    /// a raw pair fails as WGS84 degrees but falls within plausible Web Mercator bounds, it's
    /// reprojected — this is what makes the real subrectangle layer render at all; without it,
    /// every single vertex in the file would be rejected as "invalid". This is a data-quality
    /// finding worth reporting upstream (the source export should emit WGS84 consistently), not a
    /// permanent design assumption for future GeoJSON layers.
    static func coordinate(from value: Any) -> CLLocationCoordinate2D? {
        guard let pair = value as? [Any], pair.count >= 2,
              let x = numericValue(pair[0]),
              let y = numericValue(pair[1]) else {
            return nil
        }

        let asDegrees = CLLocationCoordinate2D(latitude: y, longitude: x)
        if CLLocationCoordinate2DIsValid(asDegrees) {
            return asDegrees
        }

        return webMercatorToWGS84(x: x, y: y)
    }

    private static func numericValue(_ value: Any) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    /// The usable extent of the Web Mercator (EPSG:3857) projection, in metres.
    private static let webMercatorExtent = 20_037_508.342789244
    private static let earthRadiusMetres = 6_378_137.0

    /// Converts an EPSG:3857 (Web Mercator) `(x, y)` metre pair to WGS84 degrees, returning `nil`
    /// if the values fall outside the projection's valid extent or don't produce a valid result.
    private static func webMercatorToWGS84(x: Double, y: Double) -> CLLocationCoordinate2D? {
        guard abs(x) <= webMercatorExtent, abs(y) <= webMercatorExtent else { return nil }

        let longitude = (x / earthRadiusMetres) * (180.0 / .pi)
        let latitude = (2 * atan(exp(y / earthRadiusMetres)) - .pi / 2) * (180.0 / .pi)

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    /// Parses a single coordinate ring (used for a `Polygon`'s exterior/interior rings). Returns
    /// `nil` if the ring is malformed, too short to be a ring, or contains any invalid coordinate.
    static func ring(from value: Any) -> [CLLocationCoordinate2D]? {
        guard let rawPoints = value as? [Any] else { return nil }

        var coordinates: [CLLocationCoordinate2D] = []
        coordinates.reserveCapacity(rawPoints.count)

        for rawPoint in rawPoints {
            guard let coordinate = coordinate(from: rawPoint) else { return nil }
            coordinates.append(coordinate)
        }

        return coordinates.count >= 3 ? coordinates : nil
    }

    /// Parses one Polygon's `coordinates` (an array of rings: exterior first, then any holes).
    /// A hole with invalid coordinates is dropped on its own; only an invalid **exterior** ring
    /// invalidates the whole polygon.
    static func polygon(from value: Any) -> MKPolygon? {
        guard let rawRings = value as? [Any], let firstRing = rawRings.first,
              let exterior = ring(from: firstRing) else {
            return nil
        }

        let interiorPolygons = rawRings.dropFirst().compactMap { rawRing in
            ring(from: rawRing).map { MKPolygon(coordinates: $0, count: $0.count) }
        }

        return MKPolygon(
            coordinates: exterior,
            count: exterior.count,
            interiorPolygons: interiorPolygons.isEmpty ? nil : interiorPolygons
        )
    }

    /// Parses one MultiPolygon's `coordinates` (an array of Polygon coordinate arrays). A single
    /// malformed polygon is dropped; the multipolygon is only `nil` if **none** of its polygons
    /// parse successfully.
    static func multiPolygon(from value: Any) -> MKMultiPolygon? {
        guard let rawPolygons = value as? [Any] else { return nil }

        let polygons = rawPolygons.compactMap(polygon(from:))
        return polygons.isEmpty ? nil : MKMultiPolygon(polygons)
    }

    /// Normalises a feature's geometry into a single `MKMultiPolygon`, supporting both
    /// `"Polygon"` and `"MultiPolygon"` geometry types.
    static func multiPolygon(fromFeatureGeometryType geometryType: String?, coordinates: Any?) -> MKMultiPolygon? {
        guard let geometryType, let coordinates else { return nil }

        switch geometryType {
        case "Polygon":
            return polygon(from: coordinates).map { MKMultiPolygon([$0]) }
        case "MultiPolygon":
            return multiPolygon(from: coordinates)
        default:
            return nil
        }
    }

    /// Normalises a feature's geometry into every coordinate it contains, supporting both
    /// `"Point"` and `"MultiPoint"` geometry types.
    static func coordinates(fromFeatureGeometryType geometryType: String?, coordinates: Any?) -> [CLLocationCoordinate2D] {
        guard let geometryType, let coordinates else { return [] }

        switch geometryType {
        case "Point":
            return coordinate(from: coordinates).map { [$0] } ?? []
        case "MultiPoint":
            guard let rawPoints = coordinates as? [Any] else { return [] }
            return rawPoints.compactMap(coordinate(from:))
        default:
            return []
        }
    }
}
