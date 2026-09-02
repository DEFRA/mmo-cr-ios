import XCTest
import MapKit
@testable import record_catch

final class MapLandLoaderTests: XCTestCase {

    private let samplePolygonGeoJSON = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": { "featurecla": "Land", "scalerank": 0, "min_zoom": 0.0 },
          "geometry": {
            "type": "Polygon",
            "coordinates": [[
              [-4.0, 54.0], [-3.0, 54.0], [-3.0, 55.0], [-4.0, 55.0], [-4.0, 54.0]
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
          "properties": { "featurecla": "Land" },
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

    func testLoadsPolygonGeometry() throws {
        let overlays = try MapLandLoader.load(from: Data(samplePolygonGeoJSON.utf8))

        XCTAssertEqual(overlays.count, 1)
        XCTAssertEqual(overlays.first?.multiPolygon.polygons.count, 1)
    }

    func testLoadsMultiPolygonGeometry() throws {
        let overlays = try MapLandLoader.load(from: Data(sampleMultiPolygonGeoJSON.utf8))

        XCTAssertEqual(overlays.count, 1)
        XCTAssertEqual(overlays.first?.multiPolygon.polygons.count, 2)
    }

    func testThrowsInvalidGeoJSONForMalformedJSON() {
        XCTAssertThrowsError(try MapLandLoader.load(from: Data("not geojson".utf8))) { error in
            XCTAssertEqual(error as? OfflineMapDataError, .invalidGeoJSON)
        }
    }

    func testLoadBundledParsesTheRealBundledMapResource() throws {
        let testBundle = Bundle(for: MapLandLoaderTests.self)

        let overlays = try MapLandLoader.loadBundled(bundle: testBundle)

        // The real "map.geojson" contains 7 MultiPolygon land features.
        XCTAssertEqual(overlays.count, 7)
    }

    func testLoadBundledThrowsForMissingResourceName() {
        // "does-not-exist.geojson" is never bundled, unlike the three real layer resources.
        XCTAssertThrowsError(
            try GeoJSONBundleLoader.loadData(resource: "does-not-exist", bundle: Bundle(for: MapLandLoaderTests.self))
        ) { error in
            XCTAssertEqual(error as? OfflineMapDataError, .resourceNotFound("does-not-exist"))
        }
    }
}
