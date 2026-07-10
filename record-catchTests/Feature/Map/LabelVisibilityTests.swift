import XCTest
@testable import record_catch

final class LabelVisibilityTests: XCTestCase {

    func testLabelsHiddenWhenZoomedOut() {
        XCTAssertFalse(LabelVisibility.shouldShowLabels(forLatitudeDelta: 5.0))
    }

    func testLabelsShownWhenZoomedIn() {
        XCTAssertTrue(LabelVisibility.shouldShowLabels(forLatitudeDelta: 0.5))
    }

    func testThresholdBoundaryIsExclusive() {
        let threshold = LabelVisibility.latitudeDeltaThreshold
        XCTAssertFalse(LabelVisibility.shouldShowLabels(forLatitudeDelta: threshold))
        XCTAssertTrue(LabelVisibility.shouldShowLabels(forLatitudeDelta: threshold - 0.01))
    }
}
