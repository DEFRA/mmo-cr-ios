import XCTest
import MapKit
@testable import record_catch

final class SubrectangleOverlayTests: XCTestCase {

    private func makePolygon(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> MKMultiPolygon {
        let coordinates = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        return MKMultiPolygon([MKPolygon(coordinates: coordinates, count: coordinates.count)])
    }

    func testLabelCoordinateUsesOwnBoundingRectCentreNotDatasetStatXStatY() {
        // Real-world regression: the bundled dataset's `stat_x`/`stat_y` is the centre of the
        // *parent* ICES rectangle, identical across every sibling subrectangle within it (e.g.
        // "27D84".."27D89" all carry stat_x=-11.5, stat_y=49.25). Using it for label placement
        // collapsed every sibling onto the same point, leaving only one of every ~6-9 labelled.
        // `labelCoordinate` must always be this subrectangle's own geometry, never the dataset's
        // stat_x/stat_y, however plausible-looking those values are.
        let overlay = SubrectangleOverlay(
            multiPolygon: makePolygon(minLat: 49.0, maxLat: 49.5, minLon: -12.0, maxLon: -11.0),
            properties: SubrectangleProperties(
                subCode: "27D86", icesName: "27D8", areaKM2: 4048, statX: -11.5, statY: 49.0833333333
            )
        )

        let expected = MKMapPoint(
            x: overlay.boundingMapRect.midX, y: overlay.boundingMapRect.midY
        ).coordinate

        XCTAssertEqual(overlay.labelCoordinate.latitude, expected.latitude, accuracy: 0.0001)
        XCTAssertEqual(overlay.labelCoordinate.longitude, expected.longitude, accuracy: 0.0001)
    }

    func testLabelCoordinateIsBoundingRectCentreWhenStatMissing() {
        let overlay = SubrectangleOverlay(
            multiPolygon: makePolygon(minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0),
            properties: SubrectangleProperties(subCode: "A1", icesName: nil, areaKM2: nil, statX: nil, statY: nil)
        )

        let expected = MKMapPoint(
            x: overlay.boundingMapRect.midX, y: overlay.boundingMapRect.midY
        ).coordinate

        XCTAssertEqual(overlay.labelCoordinate.latitude, expected.latitude, accuracy: 0.0001)
        XCTAssertEqual(overlay.labelCoordinate.longitude, expected.longitude, accuracy: 0.0001)
    }

    func testLabelCoordinateIsBoundingRectCentreEvenWithLargeStatValues() {
        let overlay = SubrectangleOverlay(
            multiPolygon: makePolygon(minLat: 54.0, maxLat: 55.0, minLon: -4.0, maxLon: -3.0),
            properties: SubrectangleProperties(subCode: "A1", icesName: nil, areaKM2: nil, statX: 999, statY: 999)
        )

        let expected = MKMapPoint(
            x: overlay.boundingMapRect.midX, y: overlay.boundingMapRect.midY
        ).coordinate

        XCTAssertEqual(overlay.labelCoordinate.latitude, expected.latitude, accuracy: 0.0001)
    }

    func testContainsAccountsForInteriorHoles() {
        let exterior = [
            CLLocationCoordinate2D(latitude: 54.0, longitude: -4.0),
            CLLocationCoordinate2D(latitude: 54.0, longitude: -2.0),
            CLLocationCoordinate2D(latitude: 56.0, longitude: -2.0),
            CLLocationCoordinate2D(latitude: 56.0, longitude: -4.0)
        ]
        let hole = [
            CLLocationCoordinate2D(latitude: 54.8, longitude: -3.2),
            CLLocationCoordinate2D(latitude: 54.8, longitude: -2.8),
            CLLocationCoordinate2D(latitude: 55.2, longitude: -2.8),
            CLLocationCoordinate2D(latitude: 55.2, longitude: -3.2)
        ]
        let holePolygon = MKPolygon(coordinates: hole, count: hole.count)
        let polygon = MKPolygon(coordinates: exterior, count: exterior.count, interiorPolygons: [holePolygon])
        let overlay = SubrectangleOverlay(
            multiPolygon: MKMultiPolygon([polygon]),
            properties: SubrectangleProperties(subCode: "A1", icesName: nil, areaKM2: nil, statX: nil, statY: nil)
        )

        let insideExteriorOutsideHole = MKMapPoint(CLLocationCoordinate2D(latitude: 54.2, longitude: -3.5))
        let insideHole = MKMapPoint(CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0))

        XCTAssertTrue(overlay.contains(insideExteriorOutsideHole))
        XCTAssertFalse(overlay.contains(insideHole), "A point inside the hole should not be considered inside the subrectangle")
    }
}
