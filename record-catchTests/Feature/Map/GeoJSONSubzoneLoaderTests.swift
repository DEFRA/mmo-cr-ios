import XCTest
import MapKit
@testable import record_catch

final class GeoJSONSubzoneLoaderTests: XCTestCase {

    private let sampleGeoJSON = """
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

    func testLoadsOverlaysAndAnnotationsFromValidGeoJSON() throws {
        let data = Data(sampleGeoJSON.utf8)
        let result = try GeoJSONSubzoneLoader.load(from: data)

        XCTAssertEqual(result.overlays.count, 2)
        XCTAssertEqual(result.annotations.count, 2)

        XCTAssertEqual(Set(result.overlays.map(\.subCode)), ["A1", "A2"])
        XCTAssertEqual(Set(result.annotations.map(\.subCode)), ["A1", "A2"])
    }

    func testAnnotationCoordinateMatchesOverlayCentroid() throws {
        let data = Data(sampleGeoJSON.utf8)
        let result = try GeoJSONSubzoneLoader.load(from: data)

        guard let overlay = result.overlays.first(where: { $0.subCode == "A1" }),
              let annotation = result.annotations.first(where: { $0.subCode == "A1" }) else {
            XCTFail("Expected an A1 overlay and annotation")
            return
        }

        XCTAssertEqual(annotation.coordinate.latitude, overlay.labelCoordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(annotation.coordinate.longitude, overlay.labelCoordinate.longitude, accuracy: 0.0001)
    }

    func testThrowsForInvalidGeoJSON() {
        let data = Data("not geojson".utf8)
        XCTAssertThrowsError(try GeoJSONSubzoneLoader.load(from: data))
    }

    func testLoadBundledSubzonesThrowsWhenResourceMissing() {
        // The test bundle has no "subzones.geojson" resource.
        let testBundle = Bundle(for: GeoJSONSubzoneLoaderTests.self)

        XCTAssertThrowsError(try GeoJSONSubzoneLoader.loadBundledSubzones(bundle: testBundle)) { error in
            XCTAssertEqual(error as? GeoJSONSubzoneLoaderError, .resourceNotFound)
        }
    }
}
