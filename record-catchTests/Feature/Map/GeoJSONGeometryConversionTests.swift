import XCTest
import MapKit
@testable import record_catch

final class RawGeoJSONGeometryTests: XCTestCase {

    // MARK: - coordinate(from:)

    func testCoordinateParsesLongitudeLatitudeOrder() {
        let result = RawGeoJSONGeometry.coordinate(from: [-2.6, 50.667])

        XCTAssertEqual(result?.latitude ?? 0, 50.667, accuracy: 0.0001)
        XCTAssertEqual(result?.longitude ?? 0, -2.6, accuracy: 0.0001)
    }

    func testCoordinateReturnsNilForOutOfRangeValues() {
        // A value with no plausible interpretation at all (outside both WGS84 degrees and
        // Web Mercator's metre extent).
        XCTAssertNil(RawGeoJSONGeometry.coordinate(from: [99_999_999_999.0, 99_999_999_999.0]))
    }

    func testCoordinateReprojectsWebMercatorValuesThatAreNotValidDegrees() {
        // Real defect found in the bundled subrectangles.geojson: ring vertices are encoded in
        // Web Mercator (EPSG:3857) metres, not WGS84 degrees, even though they carry the same
        // longitude-then-latitude ordering. This vertex inverse-projects to roughly
        // (-11.36, 49.17), which is within the same subrectangle as its own `stat_x`/`stat_y`.
        let result = RawGeoJSONGeometry.coordinate(from: ["-1264519.103601269889623", "6303188.702299997210503"])

        XCTAssertEqual(result?.longitude ?? 0, -11.36, accuracy: 0.05)
        XCTAssertEqual(result?.latitude ?? 0, 49.17, accuracy: 0.05)
    }

    func testCoordinateReturnsNilForMalformedInput() {
        XCTAssertNil(RawGeoJSONGeometry.coordinate(from: [1.0]))
        XCTAssertNil(RawGeoJSONGeometry.coordinate(from: "not a pair"))
        XCTAssertNil(RawGeoJSONGeometry.coordinate(from: ["a", "b"]))
    }

    // MARK: - ring(from:)

    private let squareRing: [[Double]] = [[-4.0, 54.0], [-3.0, 54.0], [-3.0, 55.0], [-4.0, 55.0], [-4.0, 54.0]]

    func testRingParsesValidCoordinates() {
        XCTAssertEqual(RawGeoJSONGeometry.ring(from: squareRing)?.count, 5)
    }

    func testRingReturnsNilWhenTooShort() {
        XCTAssertNil(RawGeoJSONGeometry.ring(from: [[-4.0, 54.0], [-3.0, 54.0]]))
    }

    func testRingReturnsNilWhenAnyCoordinateIsInvalid() {
        // 999.0 alone would now be a plausible Web Mercator metre value and reproject
        // successfully, so use a value with no plausible interpretation at all.
        let ringWithOneBadPoint = squareRing + [[99_999_999_999.0, 99_999_999_999.0]]
        XCTAssertNil(RawGeoJSONGeometry.ring(from: ringWithOneBadPoint))
    }

    // MARK: - polygon(from:)

    func testPolygonParsesExteriorRing() {
        let polygon = RawGeoJSONGeometry.polygon(from: [squareRing])
        XCTAssertEqual(polygon?.pointCount, 5)
    }

    func testPolygonDropsAnInvalidHoleButKeepsTheExterior() {
        let invalidHole: [[Double]] = [
            [99_999_999_999.0, 99_999_999_999.0], [99_999_999_998.0, 99_999_999_998.0], [99_999_999_997.0, 99_999_999_997.0]
        ]
        let polygon = RawGeoJSONGeometry.polygon(from: [squareRing, invalidHole])

        XCTAssertEqual(polygon?.pointCount, 5)
        XCTAssertNil(polygon?.interiorPolygons)
    }

    func testPolygonReturnsNilForInvalidExteriorRing() {
        XCTAssertNil(RawGeoJSONGeometry.polygon(from: [[[99_999_999_999.0, 99_999_999_999.0]]]))
    }

    // MARK: - multiPolygon(from:)

    func testMultiPolygonParsesMultiplePolygons() {
        let multiPolygon = RawGeoJSONGeometry.multiPolygon(from: [[squareRing], [squareRing]])
        XCTAssertEqual(multiPolygon?.polygons.count, 2)
    }

    func testMultiPolygonDropsAnInvalidPolygonButKeepsTheOthers() {
        let validPolygonA: [[[Double]]] = [squareRing]
        let validPolygonB: [[[Double]]] = [squareRing]
        let invalidPolygon: [[[Double]]] = [[[99_999_999_999.0, 99_999_999_999.0], [99_999_999_998.0, 99_999_999_998.0]]]

        let multiPolygon = RawGeoJSONGeometry.multiPolygon(from: [validPolygonA, validPolygonB, invalidPolygon])

        XCTAssertEqual(multiPolygon?.polygons.count, 2)
    }

    func testMultiPolygonReturnsNilWhenEveryPolygonIsInvalid() {
        XCTAssertNil(RawGeoJSONGeometry.multiPolygon(from: [[[[99_999_999_999.0, 99_999_999_999.0]]]]))
    }

    // MARK: - multiPolygon(fromFeatureGeometryType:coordinates:)

    func testFeatureMultiPolygonSupportsPolygonType() {
        let result = RawGeoJSONGeometry.multiPolygon(fromFeatureGeometryType: "Polygon", coordinates: [squareRing])
        XCTAssertEqual(result?.polygons.count, 1)
    }

    func testFeatureMultiPolygonSupportsMultiPolygonType() {
        let result = RawGeoJSONGeometry.multiPolygon(fromFeatureGeometryType: "MultiPolygon", coordinates: [[squareRing], [squareRing]])
        XCTAssertEqual(result?.polygons.count, 2)
    }

    func testFeatureMultiPolygonReturnsNilForUnsupportedGeometryType() {
        XCTAssertNil(RawGeoJSONGeometry.multiPolygon(fromFeatureGeometryType: "LineString", coordinates: squareRing))
    }

    func testFeatureMultiPolygonReturnsNilForMissingGeometry() {
        XCTAssertNil(RawGeoJSONGeometry.multiPolygon(fromFeatureGeometryType: nil, coordinates: nil))
    }

    // MARK: - coordinates(fromFeatureGeometryType:coordinates:)

    func testFeatureCoordinatesSupportsPointType() {
        let result = RawGeoJSONGeometry.coordinates(fromFeatureGeometryType: "Point", coordinates: [-4.264, 52.243])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.latitude ?? 0, 52.243, accuracy: 0.0001)
    }

    func testFeatureCoordinatesSupportsMultiPointType() {
        let result = RawGeoJSONGeometry.coordinates(fromFeatureGeometryType: "MultiPoint", coordinates: [[-2.6, 50.667]])
        XCTAssertEqual(result.count, 1)
    }

    func testFeatureCoordinatesReturnsEmptyForUnsupportedGeometryType() {
        XCTAssertTrue(RawGeoJSONGeometry.coordinates(fromFeatureGeometryType: "Polygon", coordinates: [squareRing]).isEmpty)
    }
}

final class RawGeoJSONTests: XCTestCase {

    func testThrowsInvalidGeoJSONForMalformedJSON() {
        XCTAssertThrowsError(try RawGeoJSON.features(from: Data("not geojson".utf8))) { error in
            XCTAssertEqual(error as? OfflineMapDataError, .invalidGeoJSON)
        }
    }

    func testThrowsInvalidGeoJSONForNonFeatureCollectionRoot() {
        XCTAssertThrowsError(try RawGeoJSON.features(from: Data(#"{"type": "Point"}"#.utf8)))
    }

    func testFeatureWithNullGeometryHasNoTypeOrCoordinates() throws {
        let json = #"{"type": "FeatureCollection", "features": [{"type": "Feature", "properties": {"a": 1}, "geometry": null}]}"#
        let features = try RawGeoJSON.features(from: Data(json.utf8))

        XCTAssertEqual(features.count, 1)
        XCTAssertNil(features.first?.geometryType)
        XCTAssertNotNil(features.first?.propertiesData)
    }
}

