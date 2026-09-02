import XCTest
import MapKit
@testable import record_catch

final class SubrectangleSeaOverlapTests: XCTestCase {

    private func makeSubrectangle(
        subCode: String,
        minLat: Double, maxLat: Double,
        minLon: Double, maxLon: Double
    ) -> SubrectangleOverlay {
        let coordinates = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        return SubrectangleOverlay(
            multiPolygon: MKMultiPolygon([polygon]),
            properties: SubrectangleProperties(subCode: subCode, icesName: nil, areaKM2: nil, statX: nil, statY: nil)
        )
    }

    private func makeLand(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> MapLandOverlay {
        let coordinates = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        return MapLandOverlay(multiPolygon: MKMultiPolygon([MKPolygon(coordinates: coordinates, count: coordinates.count)]))
    }

    func testAllSubrectanglesIncludedWhenNoLandOverlays() {
        let seaZone = makeSubrectangle(subCode: "SEA1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)

        let result = SubrectangleSeaOverlap.overlappingSea([seaZone], landOverlays: [])

        XCTAssertEqual(result.map(\.subCode), ["SEA1"])
    }

    func testSubrectangleEntirelyCoveredByLandIsExcluded() {
        let inlandZone = makeSubrectangle(subCode: "LAND1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        // Comfortably larger than the subrectangle on every side, so every sample point falls
        // inside it.
        let land = makeLand(minLat: 53.0, maxLat: 56.0, minLon: -5.0, maxLon: -2.0)

        let result = SubrectangleSeaOverlap.overlappingSea([inlandZone], landOverlays: [land])

        XCTAssertTrue(result.isEmpty, "A subrectangle entirely covered by land should be excluded")
    }

    func testSubrectangleEntirelyAtSeaIsIncluded() {
        let seaZone = makeSubrectangle(subCode: "SEA1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        // Nowhere near the subrectangle — bounding rects don't even intersect.
        let farAwayLand = makeLand(minLat: 10.0, maxLat: 11.0, minLon: 10.0, maxLon: 11.0)

        let result = SubrectangleSeaOverlap.overlappingSea([seaZone], landOverlays: [farAwayLand])

        XCTAssertEqual(result.map(\.subCode), ["SEA1"])
    }

    func testCoastalSubrectangleStraddlingLandAndSeaIsIncluded() {
        let coastalZone = makeSubrectangle(subCode: "COAST1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        // Covers only the western half of the subrectangle's longitude range — some of the sample
        // grid falls inside it, some doesn't, so the subrectangle has a genuine sea component.
        let land = makeLand(minLat: 53.0, maxLat: 56.0, minLon: -5.0, maxLon: -3.5)

        let result = SubrectangleSeaOverlap.overlappingSea([coastalZone], landOverlays: [land])

        XCTAssertEqual(result.map(\.subCode), ["COAST1"])
    }

    func testMixOfLandSeaAndCoastalSubrectanglesFiltersOnlyTheInlandOne() {
        let seaZone = makeSubrectangle(subCode: "SEA1", minLat: 54.0, maxLat: 55.0, minLon: -8.0, maxLon: -7.0)
        let coastalZone = makeSubrectangle(subCode: "COAST1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let inlandZone = makeSubrectangle(subCode: "LAND1", minLat: 60.0, maxLat: 61.0, minLon: -4.0, maxLon: -3.0)

        let coastalLand = makeLand(minLat: 53.0, maxLat: 56.0, minLon: -5.0, maxLon: -3.5)
        let inlandLand = makeLand(minLat: 59.0, maxLat: 62.0, minLon: -5.0, maxLon: -2.0)

        let result = SubrectangleSeaOverlap.overlappingSea(
            [seaZone, coastalZone, inlandZone],
            landOverlays: [coastalLand, inlandLand]
        )

        XCTAssertEqual(result.map(\.subCode), ["SEA1", "COAST1"])
    }
}
