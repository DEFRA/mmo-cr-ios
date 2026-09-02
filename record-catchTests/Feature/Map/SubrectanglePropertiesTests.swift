import XCTest
@testable import record_catch

final class SubrectanglePropertiesTests: XCTestCase {

    func testDecodesFullValidProperties() throws {
        let json = """
        {
            "OBJECTID_1": 25719, "OBJECTID": 25719, "ICESNAME": "27D8",
            "SOUTH": 49.0, "WEST": -12.0, "NORTH": 49.5, "EAST": -11.0,
            "AREA_KM2": 4048, "stat_x": -11.5, "stat_y": 49.0833333333,
            "sub_code": "27D86", "sub_str": 6,
            "Shape_Leng": 130867.6104, "Shape_Area": 1051127177.62
        }
        """.data(using: .utf8)!

        let properties = try JSONDecoder().decode(SubrectangleProperties.self, from: json)

        XCTAssertEqual(properties.subCode, "27D86")
        XCTAssertEqual(properties.icesName, "27D8")
        XCTAssertEqual(properties.areaKM2, 4048)
        XCTAssertEqual(properties.statX ?? 0, -11.5, accuracy: 0.0001)
        XCTAssertEqual(properties.statY ?? 0, 49.0833333333, accuracy: 0.0001)
    }

    func testDecodesWithOnlySubCodePresent() throws {
        let json = #"{"sub_code": "A1"}"#.data(using: .utf8)!

        let properties = try JSONDecoder().decode(SubrectangleProperties.self, from: json)

        XCTAssertEqual(properties.subCode, "A1")
        XCTAssertNil(properties.icesName)
        XCTAssertNil(properties.areaKM2)
        XCTAssertNil(properties.statX)
        XCTAssertNil(properties.statY)
    }

    func testThrowsWhenSubCodeMissing() {
        let json = #"{"ICESNAME": "27D8"}"#.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(SubrectangleProperties.self, from: json))
    }

    func testGeoJSONPropertiesDecoderReturnsNilForMissingSubCode() {
        let json = #"{"ICESNAME": "27D8"}"#.data(using: .utf8)!

        XCTAssertNil(GeoJSONPropertiesDecoder.decode(SubrectangleProperties.self, from: json))
    }

    func testGeoJSONPropertiesDecoderReturnsNilForNilData() {
        XCTAssertNil(GeoJSONPropertiesDecoder.decode(SubrectangleProperties.self, from: nil))
    }
}
