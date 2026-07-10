import XCTest
import MapKit
@testable import record_catch

final class SubzoneHitTesterTests: XCTestCase {

    private func makeRectangleOverlay(
        subCode: String,
        minLat: Double, maxLat: Double,
        minLon: Double, maxLon: Double
    ) -> SubzoneOverlay {
        let coordinates = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        return SubzoneOverlay(multiPolygon: MKMultiPolygon([polygon]), subCode: subCode)
    }

    func testReturnsSubCodeForPointInsideZone() {
        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let zoneB = makeRectangleOverlay(subCode: "B1", minLat: 55.0, maxLat: 56.0, minLon: -4.0, maxLon: -3.0)

        let coordinate = CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5)
        let result = SubzoneHitTester.subzoneCode(at: coordinate, in: [zoneA, zoneB])

        XCTAssertEqual(result, "A1")
    }

    func testReturnsNilWhenNoZoneContainsPoint() {
        let zoneA = makeRectangleOverlay(subCode: "A1", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)

        let coordinate = CLLocationCoordinate2D(latitude: 60.0, longitude: 0.0)
        let result = SubzoneHitTester.subzoneCode(at: coordinate, in: [zoneA])

        XCTAssertNil(result)
    }

    func testReturnsTopmostZoneWhenOverlapping() {
        // Two overlapping zones - the later element in the array should win,
        // matching MapKit's "last added is drawn on top" convention.
        let bottom = makeRectangleOverlay(subCode: "BOTTOM", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)
        let top = makeRectangleOverlay(subCode: "TOP", minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0)

        let coordinate = CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5)
        let result = SubzoneHitTester.subzoneCode(at: coordinate, in: [bottom, top])

        XCTAssertEqual(result, "TOP")
    }

    func testEmptyOverlaysReturnsNil() {
        let coordinate = CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5)
        XCTAssertNil(SubzoneHitTester.subzoneCode(at: coordinate, in: []))
    }
}
