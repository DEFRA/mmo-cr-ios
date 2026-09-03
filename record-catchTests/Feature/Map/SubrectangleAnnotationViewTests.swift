import XCTest
import MapKit
@testable import record_catch

final class SubrectangleAnnotationViewTests: XCTestCase {

    private func makeAnnotation(subCode: String = "A1") -> SubrectangleAnnotation {
        SubrectangleAnnotation(subCode: subCode, coordinate: CLLocationCoordinate2D(latitude: 54.5, longitude: -3.5))
    }

    func testViewIsNotCalloutable() {
        let annotation = makeAnnotation()
        let view = SubrectangleAnnotationView(annotation: annotation, reuseIdentifier: SubrectangleAnnotationView.reuseIdentifier)

        XCTAssertFalse(view.canShowCallout)
    }

    /// Subrectangle codes must always win collision priority over an overlapping port name (see
    /// `PortLabelAnnotationView`, `.defaultLow`) — `.required` is the only priority MapKit never
    /// hides, so switching this layer to participate in collision (`.rectangle`, previously
    /// `.none`) must not cause any subrectangle code to disappear.
    func testCollisionConfigurationAlwaysWinsOverPortLabels() {
        let annotation = makeAnnotation()
        let view = SubrectangleAnnotationView(annotation: annotation, reuseIdentifier: SubrectangleAnnotationView.reuseIdentifier)

        XCTAssertEqual(view.collisionMode, .rectangle)
        XCTAssertEqual(view.displayPriority, .required)
    }

    func testConfigureSizesBadgeToFitTheCode() {
        let annotation = makeAnnotation()
        let view = SubrectangleAnnotationView(annotation: annotation, reuseIdentifier: SubrectangleAnnotationView.reuseIdentifier)

        view.configure(subCode: "A1", isSelected: false)
        let unselectedWidth = view.bounds.width
        XCTAssertGreaterThan(unselectedWidth, 0)

        view.configure(subCode: "A1", isSelected: true)
        XCTAssertGreaterThan(view.bounds.width, 0)
    }
}
