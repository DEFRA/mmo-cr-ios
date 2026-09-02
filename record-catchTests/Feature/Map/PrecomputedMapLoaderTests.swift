import XCTest
import MapKit
@testable import record_catch

final class PrecomputedMapLoaderTests: XCTestCase {

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value)
    }

    func testLoadLandReconstructsOverlays() throws {
        let polygon = MKPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0)
        ], count: 3)
        let layer = PrecomputedMapData.LandLayer(landPolygons: [PrecomputedMapData.MultiPolygon(MKMultiPolygon([polygon]))])
        let data = try encode(layer)

        let overlays = try PrecomputedMapLoader.loadLand(from: data)
        XCTAssertEqual(overlays.count, 1)
        XCTAssertEqual(overlays[0].multiPolygon.polygons.first?.pointCount, 3)
    }

    func testLoadSubrectanglesSeparatesSelectableFromAll() throws {
        let seaPolygon = MKPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0)
        ], count: 3)
        let landPolygon = MKPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 56.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 56.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 57.0, longitude: -3.0)
        ], count: 3)

        let seaSubrectangle = PrecomputedMapData.Subrectangle(
            multiPolygon: PrecomputedMapData.MultiPolygon(MKMultiPolygon([seaPolygon])),
            properties: SubrectangleProperties(subCode: "SEA1", icesName: nil, areaKM2: nil, statX: nil, statY: nil),
            labelCoordinate: PrecomputedMapData.Coordinate(CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5)),
            overlapsSea: true
        )
        let landSubrectangle = PrecomputedMapData.Subrectangle(
            multiPolygon: PrecomputedMapData.MultiPolygon(MKMultiPolygon([landPolygon])),
            properties: SubrectangleProperties(subCode: "LAND1", icesName: nil, areaKM2: nil, statX: nil, statY: nil),
            labelCoordinate: PrecomputedMapData.Coordinate(CLLocationCoordinate2D(latitude: 56.5, longitude: -3.5)),
            overlapsSea: false
        )

        let data = try encode(PrecomputedMapData.SubrectangleLayer(subrectangles: [seaSubrectangle, landSubrectangle]))
        let result = try PrecomputedMapLoader.loadSubrectangles(from: data)

        XCTAssertEqual(result.overlays.count, 2, "Every subrectangle still gets a renderable overlay")
        XCTAssertEqual(result.selectableOverlays.count, 1)
        XCTAssertEqual(result.selectableOverlays.first?.subCode, "SEA1")
        XCTAssertEqual(result.annotations.count, 1, "Only the sea-overlapping subrectangle gets a label annotation")
        XCTAssertEqual(result.annotations.first?.subCode, "SEA1")
    }

    func testLoadPortsReconstructsMarkers() throws {
        let port = PrecomputedMapData.Port(
            portCode: 42,
            name: "Grimsby",
            coordinate: PrecomputedMapData.Coordinate(CLLocationCoordinate2D(latitude: 53.58, longitude: -0.08))
        )
        let data = try encode(PrecomputedMapData.PortLayer(ports: [port]))

        let markers = try PrecomputedMapLoader.loadPorts(from: data)
        XCTAssertEqual(markers.count, 1)
        XCTAssertEqual(markers[0].name, "Grimsby")
        XCTAssertEqual(markers[0].portCode, 42)
    }

    func testLoadFromInvalidDataThrows() {
        let invalidData = Data("not a plist".utf8)
        XCTAssertThrowsError(try PrecomputedMapLoader.loadLand(from: invalidData))
        XCTAssertThrowsError(try PrecomputedMapLoader.loadSubrectangles(from: invalidData))
        XCTAssertThrowsError(try PrecomputedMapLoader.loadPorts(from: invalidData))
    }

    func testLoadBundledResourceNotFoundThrows() {
        // The unit-test bundle itself doesn't contain the precomputed `.bin` resources under
        // their production names in every configuration path this test could run from — assert
        // the specific error type/case for a resource that definitely isn't present anywhere.
        XCTAssertThrowsError(try PrecomputedMapLoader.loadBundledLand(bundle: .init(for: XCTestCase.self))) { error in
            XCTAssertEqual(error as? OfflineMapDataError, .resourceNotFound("map-precomputed"))
        }
    }

    // MARK: - Real bundled resources (generated from the production GeoJSON — see
    // `docs/development/offline-map-precomputed-data.md`)

    func testLoadBundledLandParsesTheRealPrecomputedResource() throws {
        let overlays = try PrecomputedMapLoader.loadBundledLand(bundle: Bundle(for: PrecomputedMapLoaderTests.self))
        XCTAssertEqual(overlays.count, 7, "map.geojson has 7 land features")
    }

    func testLoadBundledSubrectanglesParsesTheRealPrecomputedResource() throws {
        let result = try PrecomputedMapLoader.loadBundledSubrectangles(bundle: Bundle(for: PrecomputedMapLoaderTests.self))
        XCTAssertEqual(result.overlays.count, 3465, "subrectangles.geojson has 3465 features")
        XCTAssertFalse(result.selectableOverlays.isEmpty)
        XCTAssertTrue(result.selectableOverlays.count < result.overlays.count, "some subrectangles are entirely on land")
        XCTAssertEqual(result.annotations.count, result.selectableOverlays.count)
    }

    func testLoadBundledPortsParsesTheRealPrecomputedResource() throws {
        let markers = try PrecomputedMapLoader.loadBundledPorts(bundle: Bundle(for: PrecomputedMapLoaderTests.self))
        XCTAssertEqual(markers.count, 938, "ports.geojson has 938 features")
    }
}
