import XCTest
import MapKit
@testable import record_catch

final class PortMapCameraTests: XCTestCase {

    private let port = CLLocationCoordinate2D(latitude: 54.0, longitude: -3.0)

    // Explicitly qualified with the app module name (`record_catch`): `Features/Map/MapLandOverlay.swift`
    // is also compiled directly into this test target (see the project's file-system-synchronized
    // group exceptions), so the unqualified name `MapLandOverlay` would otherwise resolve to that
    // separate, test-target-local type rather than the one `PortMapCamera` (imported via
    // `@testable import`) actually expects — the two are distinct nominal types despite sharing a name.
    private func makeLand(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> record_catch.MapLandOverlay {
        let coordinates = [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLon),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)
        ]
        return record_catch.MapLandOverlay(multiPolygon: MKMultiPolygon([MKPolygon(coordinates: coordinates, count: coordinates.count)]))
    }

    // MARK: - Span

    func test_region_usesSubrectangleGridSpan_bySizedToShowRoughlyOneIcesRectangle() {
        let region = PortMapCamera.region(forPort: port, avoiding: [])

        XCTAssertEqual(region.span.latitudeDelta, PortMapCamera.subrectangleGridSpan.latitudeDelta)
        XCTAssertEqual(region.span.longitudeDelta, PortMapCamera.subrectangleGridSpan.longitudeDelta)
    }

    func test_region_withExplicitSpan_usesIt() {
        let span = MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 2.0)

        let region = PortMapCamera.region(forPort: port, avoiding: [], span: span)

        XCTAssertEqual(region.span.latitudeDelta, 1.0)
        XCTAssertEqual(region.span.longitudeDelta, 2.0)
    }

    // MARK: - Centre biasing

    func test_region_withNoLandOverlays_isCenteredOnThePort() {
        let region = PortMapCamera.region(forPort: port, avoiding: [])

        XCTAssertEqual(region.center.latitude, port.latitude)
        XCTAssertEqual(region.center.longitude, port.longitude)
    }

    func test_region_withLandEntirelySurroundingThePort_isCenteredOnThePort() {
        // Every candidate sample direction lands inside this huge land block, so there's no clear
        // sea direction to bias towards.
        let land = makeLand(minLat: 40.0, maxLat: 60.0, minLon: -20.0, maxLon: 10.0)

        let region = PortMapCamera.region(forPort: port, avoiding: [land])

        XCTAssertEqual(region.center.latitude, port.latitude)
        XCTAssertEqual(region.center.longitude, port.longitude)
    }

    func test_region_withLandToTheWest_isBiasedEast() {
        // Land covers everything west of the port's longitude; every sample to the west (and the
        // west-leaning diagonals) is on land, but due-east samples are all sea.
        let land = makeLand(minLat: 40.0, maxLat: 60.0, minLon: -20.0, maxLon: port.longitude)

        let region = PortMapCamera.region(forPort: port, avoiding: [land])

        XCTAssertEqual(region.center.latitude, port.latitude, accuracy: 0.0001)
        XCTAssertGreaterThan(region.center.longitude, port.longitude)
    }

    func test_region_withLandToTheEast_isBiasedWest() {
        let land = makeLand(minLat: 40.0, maxLat: 60.0, minLon: port.longitude, maxLon: 10.0)

        let region = PortMapCamera.region(forPort: port, avoiding: [land])

        XCTAssertEqual(region.center.latitude, port.latitude, accuracy: 0.0001)
        XCTAssertLessThan(region.center.longitude, port.longitude)
    }

    func test_region_withLandToTheNorth_isBiasedSouth() {
        let land = makeLand(minLat: port.latitude, maxLat: 60.0, minLon: -20.0, maxLon: 10.0)

        let region = PortMapCamera.region(forPort: port, avoiding: [land])

        XCTAssertLessThan(region.center.latitude, port.latitude)
    }

    func test_region_biasedCenter_neverMovesTheFullHalfSpan_soThePortStaysOnScreen() {
        let land = makeLand(minLat: 40.0, maxLat: 60.0, minLon: -20.0, maxLon: port.longitude)

        let region = PortMapCamera.region(forPort: port, avoiding: [land])

        let maxOffset = region.span.longitudeDelta / 2
        XCTAssertLessThan(abs(region.center.longitude - port.longitude), maxOffset)
    }

    func test_region_withLandFarAway_isCenteredOnThePort() {
        // Bounding rects don't intersect any sample point near the port at all.
        let farAwayLand = makeLand(minLat: 10.0, maxLat: 11.0, minLon: 10.0, maxLon: 11.0)

        let region = PortMapCamera.region(forPort: port, avoiding: [farAwayLand])

        XCTAssertEqual(region.center.latitude, port.latitude)
        XCTAssertEqual(region.center.longitude, port.longitude)
    }

    // MARK: - initialRegion(forPort:defaultRegion:)

    func test_initialRegion_withNilPortCoordinate_returnsDefaultRegionUnchanged() {
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 55.0, longitude: -3.5),
            span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 8.0)
        )

        let region = PortMapCamera.initialRegion(forPort: nil, defaultRegion: defaultRegion)

        XCTAssertEqual(region.center.latitude, defaultRegion.center.latitude)
        XCTAssertEqual(region.center.longitude, defaultRegion.center.longitude)
        XCTAssertEqual(region.span.latitudeDelta, defaultRegion.span.latitudeDelta)
        XCTAssertEqual(region.span.longitudeDelta, defaultRegion.span.longitudeDelta)
    }

    func test_initialRegion_withPortCoordinate_framesThePortUsingTheRealBundledLandLayer() {
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 8.0)
        )
        let portCoordinate = PortCoordinate(latitude: 54.0, longitude: -3.0)
        let testBundle = Bundle(for: PortMapCameraTests.self)

        let region = PortMapCamera.initialRegion(
            forPort: portCoordinate,
            defaultRegion: defaultRegion,
            bundle: testBundle
        )

        XCTAssertEqual(region.span.latitudeDelta, PortMapCamera.subrectangleGridSpan.latitudeDelta)
        XCTAssertEqual(region.span.longitudeDelta, PortMapCamera.subrectangleGridSpan.longitudeDelta)
        // Framed near the port (within one span of it), whichever direction it was biased towards.
        XCTAssertEqual(region.center.latitude, portCoordinate.latitude, accuracy: region.span.latitudeDelta)
        XCTAssertEqual(region.center.longitude, portCoordinate.longitude, accuracy: region.span.longitudeDelta)
    }
}
