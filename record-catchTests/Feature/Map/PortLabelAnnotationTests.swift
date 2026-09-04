import XCTest
import MapKit
@testable import record_catch

final class PortLabelAnnotationTests: XCTestCase {

    func testInitPreservesValues() {
        let coordinate = CLLocationCoordinate2D(latitude: 50.667, longitude: -2.6)
        let annotation = PortLabelAnnotation(portCode: 678, name: "Abbotsbury", coordinate: coordinate)

        XCTAssertEqual(annotation.portCode, 678)
        XCTAssertEqual(annotation.name, "Abbotsbury")
        XCTAssertEqual(annotation.coordinate.latitude, coordinate.latitude)
        XCTAssertEqual(annotation.coordinate.longitude, coordinate.longitude)
    }

    func testAnnotationsForMarkersProducesOnePerMarkerPreservingOrder() {
        let markers = [
            PortMarker(portCode: 1, name: "North", coordinate: CLLocationCoordinate2D(latitude: 55.0, longitude: -3.0)),
            PortMarker(portCode: 2, name: "South", coordinate: CLLocationCoordinate2D(latitude: 50.0, longitude: -5.0))
        ]

        let annotations = PortLabelAnnotation.annotations(for: markers)

        XCTAssertEqual(annotations.count, 2)
        XCTAssertEqual(annotations[0].portCode, 1)
        XCTAssertEqual(annotations[0].name, "North")
        XCTAssertEqual(annotations[1].portCode, 2)
        XCTAssertEqual(annotations[1].name, "South")
    }

    func testAnnotationsForEmptyMarkersProducesEmptyArray() {
        XCTAssertTrue(PortLabelAnnotation.annotations(for: []).isEmpty)
    }
}

final class PortLabelAnnotationViewTests: XCTestCase {

    private func makeAnnotation() -> PortLabelAnnotation {
        PortLabelAnnotation(
            portCode: 678,
            name: "Abbotsbury",
            coordinate: CLLocationCoordinate2D(latitude: 50.667, longitude: -2.6)
        )
    }

    /// Ports must never be selectable or show a callout, regardless of how their name is drawn —
    /// unlike `PortsOverlay` (an `MKOverlay`, structurally never tappable), an `MKAnnotationView`
    /// *can* receive touches by default, so this configuration is the thing that actually
    /// preserves the guarantee and must never regress.
    func testViewIsNonInteractive() {
        let annotation = makeAnnotation()
        let view = PortLabelAnnotationView(annotation: annotation, reuseIdentifier: PortLabelAnnotationView.reuseIdentifier)

        XCTAssertFalse(view.canShowCallout)
        XCTAssertFalse(view.isEnabled)
        XCTAssertFalse(view.isUserInteractionEnabled)
    }

    /// Collision handling is deliberately off (see `PortLabelAnnotationView.configureView`) — a
    /// port name must always render, never be silently hidden by MapKit's own collision system.
    func testCollisionIsDisabled() {
        let annotation = makeAnnotation()
        let view = PortLabelAnnotationView(annotation: annotation, reuseIdentifier: PortLabelAnnotationView.reuseIdentifier)

        XCTAssertEqual(view.collisionMode, .none)
    }

    func testConfigureSizesBoundsToFitTheName() {
        let annotation = makeAnnotation()
        let view = PortLabelAnnotationView(annotation: annotation, reuseIdentifier: PortLabelAnnotationView.reuseIdentifier)

        view.configure(name: "Abbotsbury")
        XCTAssertGreaterThan(view.bounds.width, 0)
        XCTAssertGreaterThan(view.bounds.height, 0)

        let shortWidth = view.bounds.width
        view.configure(name: "A much longer port name than before")
        XCTAssertGreaterThan(view.bounds.width, shortWidth)
    }

    func testConfigureOffsetsCenterToTheRightKeepingVerticalCentering() {
        let annotation = makeAnnotation()
        let view = PortLabelAnnotationView(annotation: annotation, reuseIdentifier: PortLabelAnnotationView.reuseIdentifier)

        view.configure(name: "Abbotsbury")

        XCTAssertGreaterThan(view.centerOffset.x, 0, "Label must sit to the right of the port coordinate, not on top of it")
        XCTAssertEqual(view.centerOffset.y, 0, "Label must stay vertically centred on the port coordinate")
    }
}
