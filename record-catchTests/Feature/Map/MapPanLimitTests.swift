import XCTest
import MapKit
@testable import record_catch

final class MapPanLimitTests: XCTestCase {

    private let center = CLLocationCoordinate2D(latitude: 55.0, longitude: -3.5)

    func test_maxPanDistance_isApproximately100Miles() {
        // 100 miles in metres, computed the same way as the source (mile = 1_609.344m) — guards
        // against the constant silently drifting from "about 100 miles" (the product ask).
        XCTAssertEqual(MapPanLimit.maxPanDistance, 100 * 1_609.344, accuracy: 0.001)
    }

    func test_boundaryRegion_centresOnTheGivenCoordinate() {
        let region = MapPanLimit.boundaryRegion(center: center)

        XCTAssertEqual(region.center.latitude, center.latitude, accuracy: 0.0001)
        XCTAssertEqual(region.center.longitude, center.longitude, accuracy: 0.0001)
    }

    func test_boundaryRegion_defaultDistance_matchesMaxPanDistance() {
        let region = MapPanLimit.boundaryRegion(center: center)
        let expected = MKCoordinateRegion(
            center: center,
            latitudinalMeters: MapPanLimit.maxPanDistance * 2,
            longitudinalMeters: MapPanLimit.maxPanDistance * 2
        )

        XCTAssertEqual(region.span.latitudeDelta, expected.span.latitudeDelta, accuracy: 0.0001)
        XCTAssertEqual(region.span.longitudeDelta, expected.span.longitudeDelta, accuracy: 0.0001)
    }

    func test_boundaryRegion_widerDistance_producesWiderSpan() {
        let narrow = MapPanLimit.boundaryRegion(center: center, distance: 10_000)
        let wide = MapPanLimit.boundaryRegion(center: center, distance: 200_000)

        XCTAssertGreaterThan(wide.span.latitudeDelta, narrow.span.latitudeDelta)
        XCTAssertGreaterThan(wide.span.longitudeDelta, narrow.span.longitudeDelta)
    }

    /// Regression guard for the doubling in `boundaryRegion`: a `distance` of X metres must
    /// produce the same span as directly asking for a region X*2 metres wide — if the doubling
    /// were ever dropped, the user could only pan half as far as `maxPanDistance` promises.
    func test_boundaryRegion_isARadiusNotADiameter() {
        let distance: CLLocationDistance = 50_000
        let region = MapPanLimit.boundaryRegion(center: center, distance: distance)
        let expectedFullSpanRegion = MKCoordinateRegion(
            center: center,
            latitudinalMeters: distance * 2,
            longitudinalMeters: distance * 2
        )

        XCTAssertEqual(region.span.latitudeDelta, expectedFullSpanRegion.span.latitudeDelta, accuracy: 0.0001)
        XCTAssertEqual(region.span.longitudeDelta, expectedFullSpanRegion.span.longitudeDelta, accuracy: 0.0001)
    }

    /// `MKMapView.CameraBoundary(coordinateRegion:)` is failable — this guards that a real,
    /// UK-latitude coordinate with the default 100-mile limit always produces a valid boundary,
    /// so `OfflineMapView.makeUIView`'s fail-soft branch is never silently exercised in practice.
    func test_boundaryRegion_producesAValidCameraBoundary() {
        let region = MapPanLimit.boundaryRegion(center: center)
        XCTAssertNotNil(MKMapView.CameraBoundary(coordinateRegion: region))
    }
}
