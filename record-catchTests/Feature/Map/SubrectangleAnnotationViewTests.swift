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

    /// Collision handling is deliberately off (see `SubrectangleAnnotationView.configureLabel`) —
    /// a subrectangle code must always render, never be silently hidden by MapKit's own collision
    /// system.
    func testCollisionIsDisabled() {
        let annotation = makeAnnotation()
        let view = SubrectangleAnnotationView(annotation: annotation, reuseIdentifier: SubrectangleAnnotationView.reuseIdentifier)

        XCTAssertEqual(view.collisionMode, .none)
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
