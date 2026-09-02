import XCTest
import MapKit
@testable import record_catch

final class SubrectangleLoaderTests: XCTestCase {

    private let samplePolygonGeoJSON = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": { "sub_code": "A1" },
          "geometry": {
            "type": "Polygon",
            "coordinates": [[
              [-4.0, 54.0], [-3.0, 54.0], [-3.0, 55.0], [-4.0, 55.0], [-4.0, 54.0]
            ]]
          }
        },
        {
          "type": "Feature",
          "properties": { "sub_code": "A2" },
          "geometry": {
            "type": "Polygon",
            "coordinates": [[
              [-3.0, 54.0], [-2.0, 54.0], [-2.0, 55.0], [-3.0, 55.0], [-3.0, 54.0]
            ]]
          }
        }
      ]
    }
    """

    private let sampleMultiPolygonGeoJSON = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": { "sub_code": "B1" },
          "geometry": {
            "type": "MultiPolygon",
            "coordinates": [
              [[[-4.0, 54.0], [-3.0, 54.0], [-3.0, 55.0], [-4.0, 55.0], [-4.0, 54.0]]],
              [[[-2.0, 54.0], [-1.0, 54.0], [-1.0, 55.0], [-2.0, 55.0], [-2.0, 54.0]]]
            ]
          }
        }
      ]
    }
    """

    func testLoadsOverlaysAndAnnotationsFromValidPolygonGeoJSON() throws {
        let data = Data(samplePolygonGeoJSON.utf8)
        let result = try SubrectangleLoader.load(from: data)

        XCTAssertEqual(result.overlays.count, 2)
        XCTAssertEqual(result.annotations.count, 2)
        XCTAssertEqual(Set(result.overlays.map(\.subCode)), ["A1", "A2"])
        XCTAssertEqual(Set(result.annotations.map(\.subCode)), ["A1", "A2"])
    }

    func testLoadsMultiPolygonGeometryAsSingleOverlayWithBothPolygons() throws {
        let data = Data(sampleMultiPolygonGeoJSON.utf8)
        let result = try SubrectangleLoader.load(from: data)

        XCTAssertEqual(result.overlays.count, 1)
        XCTAssertEqual(result.overlays.first?.multiPolygon.polygons.count, 2)
        XCTAssertEqual(result.overlays.first?.subCode, "B1")
    }

    func testAnnotationCoordinateMatchesOverlayLabelCoordinate() throws {
        let data = Data(samplePolygonGeoJSON.utf8)
        let result = try SubrectangleLoader.load(from: data)

        guard let overlay = result.overlays.first(where: { $0.subCode == "A1" }),
              let annotation = result.annotations.first(where: { $0.subCode == "A1" }) else {
            XCTFail("Expected an A1 overlay and annotation")
            return
        }

        XCTAssertEqual(annotation.coordinate.latitude, overlay.labelCoordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(annotation.coordinate.longitude, overlay.labelCoordinate.longitude, accuracy: 0.0001)
    }

    func testSkipsFeatureWithMissingSubCodeWithoutFailingTheWholeLoad() throws {
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": { "ICESNAME": "27D8" },
              "geometry": {
                "type": "Polygon",
                "coordinates": [[
                  [-4.0, 54.0], [-3.0, 54.0], [-3.0, 55.0], [-4.0, 55.0], [-4.0, 54.0]
                ]]
              }
            },
            {
              "type": "Feature",
              "properties": { "sub_code": "A2" },
              "geometry": {
                "type": "Polygon",
                "coordinates": [[
                  [-3.0, 54.0], [-2.0, 54.0], [-2.0, 55.0], [-3.0, 55.0], [-3.0, 54.0]
                ]]
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let result = try SubrectangleLoader.load(from: data)

        XCTAssertEqual(result.overlays.count, 1)
        XCTAssertEqual(result.overlays.first?.subCode, "A2")
    }

    func testSkipsFeatureWithInvalidCoordinateWithoutFailingTheWholeLoad() throws {
        // A coordinate with no plausible interpretation as either WGS84 degrees or Web Mercator
        // metres (see `RawGeoJSONGeometry.coordinate(from:)`) must not take down every other
        // feature's load.
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": { "sub_code": "BAD1" },
              "geometry": {
                "type": "Polygon",
                "coordinates": [[
                  [99999999999.0, 99999999999.0], [-3.0, 54.0], [-3.0, 55.0]
                ]]
              }
            },
            {
              "type": "Feature",
              "properties": { "sub_code": "A2" },
              "geometry": {
                "type": "Polygon",
                "coordinates": [[
                  [-3.0, 54.0], [-2.0, 54.0], [-2.0, 55.0], [-3.0, 55.0], [-3.0, 54.0]
                ]]
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)

        let result = try SubrectangleLoader.load(from: data)

        XCTAssertEqual(result.overlays.count, 1)
        XCTAssertEqual(result.overlays.first?.subCode, "A2")
    }

    func testThrowsInvalidGeoJSONForMalformedJSON() {
        let data = Data("not geojson".utf8)
        XCTAssertThrowsError(try SubrectangleLoader.load(from: data)) { error in
            XCTAssertEqual(error as? OfflineMapDataError, .invalidGeoJSON)
        }
    }

    func testLoadBundledParsesTheRealBundledSubrectanglesResource() throws {
        // "subrectangles.geojson" is bundled with the test target too (see the Xcode project's
        // synchronized-group exceptions), so this exercises the real ~3,500-feature dataset,
        // including its one known stray non-WGS84 coordinate (see `RawGeoJSON`'s doc comment).
        let testBundle = Bundle(for: SubrectangleLoaderTests.self)

        let result = try SubrectangleLoader.loadBundled(bundle: testBundle)

        XCTAssertFalse(result.overlays.isEmpty)
        XCTAssertEqual(result.overlays.count, result.annotations.count)
        XCTAssertTrue(result.overlays.contains { $0.subCode == "27D86" })
    }
}
