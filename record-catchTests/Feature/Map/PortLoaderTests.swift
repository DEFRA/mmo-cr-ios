import XCTest
import MapKit
@testable import record_catch

final class PortLoaderTests: XCTestCase {

    private let sampleMultiPointGeoJSON = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": { "port": "Abbotsbury", "port_code": 678.0, "lat": 50.667, "long_": -2.6 },
          "geometry": { "type": "MultiPoint", "coordinates": [[-2.6, 50.667]] }
        }
      ]
    }
    """

    private let samplePointGeoJSON = """
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": { "port": "Aberaeron", "port_code": 844.0, "lat": 52.243, "long_": -4.264 },
          "geometry": { "type": "Point", "coordinates": [-4.264, 52.243] }
        }
      ]
    }
    """

    func testParsesMultiPointGeometryWithCorrectLongitudeLatitudeOrder() throws {
        let markers = try PortLoader.load(from: Data(sampleMultiPointGeoJSON.utf8))

        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers.first?.name, "Abbotsbury")
        XCTAssertEqual(markers.first?.portCode, 678.0)
        // GeoJSON coordinates are [longitude, latitude] - confirm they weren't swapped.
        XCTAssertEqual(markers.first?.coordinate.latitude ?? 0, 50.667, accuracy: 0.0001)
        XCTAssertEqual(markers.first?.coordinate.longitude ?? 0, -2.6, accuracy: 0.0001)
    }

    func testParsesPointGeometry() throws {
        let markers = try PortLoader.load(from: Data(samplePointGeoJSON.utf8))

        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers.first?.name, "Aberaeron")
        XCTAssertEqual(markers.first?.coordinate.latitude ?? 0, 52.243, accuracy: 0.0001)
        XCTAssertEqual(markers.first?.coordinate.longitude ?? 0, -4.264, accuracy: 0.0001)
    }

    func testSkipsFeatureWithMissingProperties() throws {
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": { "lat": 50.667, "long_": -2.6 },
              "geometry": { "type": "MultiPoint", "coordinates": [[-2.6, 50.667]] }
            }
          ]
        }
        """
        let markers = try PortLoader.load(from: Data(json.utf8))

        XCTAssertTrue(markers.isEmpty, "A feature missing required 'port'/'port_code' properties should be skipped")
    }

    func testSkipsFeatureWithNoGeometryAndNoValidFallback() throws {
        // `"geometry": null` is valid GeoJSON for an unlocated feature; the loader should skip it
        // (rather than fail the whole load) when there's also no lat/long fallback in properties.
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": { "port": "Nowhere", "port_code": 1.0 },
              "geometry": null
            }
          ]
        }
        """
        let markers = try PortLoader.load(from: Data(json.utf8))

        XCTAssertTrue(markers.isEmpty)
    }

    func testFallsBackToPropertyLatLongWhenGeometryIsMissing() throws {
        let json = """
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "properties": { "port": "Fallback Harbour", "port_code": 2.0, "lat": 51.5, "long_": -1.0 },
              "geometry": null
            }
          ]
        }
        """
        let markers = try PortLoader.load(from: Data(json.utf8))

        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers.first?.coordinate.latitude ?? 0, 51.5, accuracy: 0.0001)
        XCTAssertEqual(markers.first?.coordinate.longitude ?? 0, -1.0, accuracy: 0.0001)
    }

    func testThrowsInvalidGeoJSONForMalformedJSON() {
        XCTAssertThrowsError(try PortLoader.load(from: Data("not geojson".utf8))) { error in
            XCTAssertEqual(error as? OfflineMapDataError, .invalidGeoJSON)
        }
    }

    func testLoadBundledParsesTheRealBundledPortsResource() throws {
        let testBundle = Bundle(for: PortLoaderTests.self)

        let markers = try PortLoader.loadBundled(bundle: testBundle)

        // The real "ports.geojson" contains 938 port features.
        XCTAssertEqual(markers.count, 938)
        XCTAssertTrue(markers.contains { $0.name == "Abbotsbury" })
    }
}
