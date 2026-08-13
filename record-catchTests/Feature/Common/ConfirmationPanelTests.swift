import XCTest
@testable import record_catch

final class ConfirmationPanelTests: XCTestCase {

    func test_accessibilityLabel_combinesHeadingReferenceLabelAndNumber() {
        let label = ConfirmationPanel.accessibilityLabel(
            heading: "Your catch record has been submitted",
            referenceLabel: "Your catch record reference",
            referenceNumber: "A1234520260727150815"
        )

        XCTAssertEqual(
            label,
            "Your catch record has been submitted. Your catch record reference A1234520260727150815"
        )
    }
}
