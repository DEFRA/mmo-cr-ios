import XCTest
import MapKit
@testable import record_catch

final class PrecomputedMapDataTests: XCTestCase {

    func testCoordinateRoundTrips() {
        let original = CLLocationCoordinate2D(latitude: 54.123, longitude: -3.456)
        let precomputed = PrecomputedMapData.Coordinate(original)

        XCTAssertEqual(precomputed.coordinate.latitude, original.latitude, accuracy: 0.000001)
        XCTAssertEqual(precomputed.coordinate.longitude, original.longitude, accuracy: 0.000001)
    }

    func testPolygonRoundTripsExteriorAndHoles() {
        let exterior = [
            CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -4.0)
        ]
        let hole = [
            CLLocationCoordinate2D(latitude: 54.2, longitude: -3.8),
            CLLocationCoordinate2D(latitude: 54.2, longitude: -3.2),
            CLLocationCoordinate2D(latitude: 54.8, longitude: -3.2)
        ]
        let holePolygon = MKPolygon(coordinates: hole, count: hole.count)
        let original = MKPolygon(coordinates: exterior, count: exterior.count, interiorPolygons: [holePolygon])

        let precomputed = PrecomputedMapData.Polygon(original)
        XCTAssertEqual(precomputed.exterior.count, exterior.count)
        XCTAssertEqual(precomputed.holes.count, 1)
        XCTAssertEqual(precomputed.holes[0].count, hole.count)

        let reconstructed = precomputed.polygon
        XCTAssertEqual(reconstructed.pointCount, exterior.count)
        XCTAssertEqual(reconstructed.interiorPolygons?.count, 1)
        XCTAssertEqual(reconstructed.interiorPolygons?.first?.pointCount, hole.count)
    }

    func testPolygonWithNoHolesRoundTrips() {
        let exterior = [
            CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0)
        ]
        let original = MKPolygon(coordinates: exterior, count: exterior.count)

        let precomputed = PrecomputedMapData.Polygon(original)
        XCTAssertTrue(precomputed.holes.isEmpty)
        XCTAssertNil(precomputed.polygon.interiorPolygons)
    }

    func testMultiPolygonRoundTrips() {
        let polygonA = MKPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0)
        ], count: 3)
        let polygonB = MKPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 56.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 56.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 57.0, longitude: -3.0)
        ], count: 3)
        let original = MKMultiPolygon([polygonA, polygonB])

        let precomputed = PrecomputedMapData.MultiPolygon(original)
        XCTAssertEqual(precomputed.polygons.count, 2)

        let reconstructed = precomputed.multiPolygon
        XCTAssertEqual(reconstructed.polygons.count, 2)
    }

    func testSubrectangleLayerEncodesAndDecodesViaPropertyList() throws {
        let polygon = MKPolygon(coordinates: [
            CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0),
            CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0)
        ], count: 3)
        let subrectangle = PrecomputedMapData.Subrectangle(
            multiPolygon: PrecomputedMapData.MultiPolygon(MKMultiPolygon([polygon])),
            properties: SubrectangleProperties(subCode: "27D86", icesName: "27D8", areaKM2: 123.4, statX: -11.5, statY: 49.25),
            labelCoordinate: PrecomputedMapData.Coordinate(CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5)),
            overlapsSea: true
        )
        let layer = PrecomputedMapData.SubrectangleLayer(subrectangles: [subrectangle])

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(layer)

        let decoded = try PropertyListDecoder().decode(PrecomputedMapData.SubrectangleLayer.self, from: data)
        XCTAssertEqual(decoded.subrectangles.count, 1)
        XCTAssertEqual(decoded.subrectangles[0].properties.subCode, "27D86")
        XCTAssertEqual(decoded.subrectangles[0].overlapsSea, true)
        XCTAssertEqual(decoded.subrectangles[0].labelCoordinate.latitude, 54.5, accuracy: 0.000001)
    }

    func testPortLayerEncodesAndDecodesViaPropertyList() throws {
        let port = PrecomputedMapData.Port(
            portCode: 123,
            name: "Whitby",
            coordinate: PrecomputedMapData.Coordinate(CLLocationCoordinate2D(latitude: 54.49, longitude: -0.62))
        )
        let layer = PrecomputedMapData.PortLayer(ports: [port])

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(layer)

        let decoded = try PropertyListDecoder().decode(PrecomputedMapData.PortLayer.self, from: data)
        XCTAssertEqual(decoded.ports.count, 1)
        XCTAssertEqual(decoded.ports[0].name, "Whitby")
        XCTAssertEqual(decoded.ports[0].portCode, 123)
    }
}
