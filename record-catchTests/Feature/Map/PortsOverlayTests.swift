import XCTest
import MapKit
@testable import record_catch

final class PortsOverlayTests: XCTestCase {

    func testEmptyMarkersProducesNullBoundingRect() {
        let overlay = PortsOverlay(markers: [])

        XCTAssertTrue(overlay.boundingMapRect.isNull)
    }

    func testBoundingRectCoversAllMarkers() {
        let markers = [
            PortMarker(portCode: 1, name: "North", coordinate: CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0)),
            PortMarker(portCode: 2, name: "South", coordinate: CLLocationCoordinate2D(latitude: 50.0, longitude: -5.0))
        ]

        let overlay = PortsOverlay(markers: markers)

        for marker in markers {
            XCTAssertTrue(overlay.boundingMapRect.contains(MKMapPoint(marker.coordinate)))
        }
    }

    func testPortMarkerEquality() {
        let coordinate = CLLocationCoordinate2D(latitude: 50.667, longitude: -2.6)
        let a = PortMarker(portCode: 678, name: "Abbotsbury", coordinate: coordinate)
        let b = PortMarker(portCode: 678, name: "Abbotsbury", coordinate: coordinate)
        let differentCode = PortMarker(portCode: 999, name: "Abbotsbury", coordinate: coordinate)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, differentCode)
    }
}
