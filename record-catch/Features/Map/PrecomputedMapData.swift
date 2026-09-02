import CoreGraphics
import Foundation
import MapKit

/// Codable mirrors of the map's MapKit-backed types, used only to precompute the three bundled
/// GeoJSON layers **once, offline**, and ship the ready-to-use result in the app bundle.
///
/// `map.geojson`/`subrectangles.geojson`/`ports.geojson` are static — they never change at
/// runtime — so every expensive step `RawGeoJSON`/`RawGeoJSONGeometry`/`SubrectangleSeaOverlap`
/// perform (JSON parsing, the Web Mercator/string-coordinate reprojection fallback, and the
/// sea-overlap point-sampling) is a fixed function of that static data. Doing that work at build
/// time and shipping the *result* (see `PrecomputedMapLoader`) means the device never repeats it:
/// not once per launch, and not once per catch record, which is otherwise the common case.
///
/// These types are intentionally MapKit-independent (plain `Double`s, not `CLLocationCoordinate2D`
/// directly) purely so they round-trip cleanly through `PropertyListEncoder`/`PropertyListDecoder`.
///
/// See `docs/development/offline-map-precomputed-data.md` for how/when to regenerate the bundled
/// `.plist` files these types (de)serialise.
enum PrecomputedMapData {

    struct Coordinate: Codable {
        let latitude: CLLocationDegrees
        let longitude: CLLocationDegrees

        init(_ coordinate: CLLocationCoordinate2D) {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    /// A single polygon ring's coordinates as a flat `[Coordinate]` array (closed or open, matching
    /// whatever `MKPolygon.points()` already returned).
    struct Polygon: Codable {
        let exterior: [Coordinate]
        let holes: [[Coordinate]]

        init(_ polygon: MKPolygon) {
            exterior = Self.coordinates(of: polygon)
            holes = (polygon.interiorPolygons ?? []).map(Self.coordinates(of:))
        }

        private static func coordinates(of polygon: MKPolygon) -> [Coordinate] {
            let mapPoints = polygon.points()
            return (0..<polygon.pointCount).map { Coordinate(mapPoints[$0].coordinate) }
        }

        /// Reconstructs the `MKPolygon` this was precomputed from.
        var polygon: MKPolygon {
            let exteriorCoordinates = exterior.map(\.coordinate)
            let holePolygons = holes.map { hole -> MKPolygon in
                let coordinates = hole.map(\.coordinate)
                return MKPolygon(coordinates: coordinates, count: coordinates.count)
            }
            return MKPolygon(
                coordinates: exteriorCoordinates,
                count: exteriorCoordinates.count,
                interiorPolygons: holePolygons.isEmpty ? nil : holePolygons
            )
        }
    }

    struct MultiPolygon: Codable {
        let polygons: [Polygon]

        init(_ multiPolygon: MKMultiPolygon) {
            polygons = multiPolygon.polygons.map(Polygon.init)
        }

        var multiPolygon: MKMultiPolygon {
            MKMultiPolygon(polygons.map(\.polygon))
        }
    }

    /// The precomputed main map ("map.geojson") layer.
    struct LandLayer: Codable {
        let landPolygons: [MultiPolygon]
    }

    /// A single precomputed subrectangle, with its sea-overlap already resolved.
    struct Subrectangle: Codable {
        let multiPolygon: MultiPolygon
        let properties: SubrectangleProperties
        let labelCoordinate: Coordinate
        /// Precomputed once by `SubrectangleSeaOverlap` at generation time — the app never
        /// re-runs the point-sampling this represents.
        let overlapsSea: Bool
    }

    struct SubrectangleLayer: Codable {
        let subrectangles: [Subrectangle]
    }

    struct Port: Codable {
        let portCode: Double
        let name: String
        let coordinate: Coordinate
    }

    struct PortLayer: Codable {
        let ports: [Port]
    }
}
