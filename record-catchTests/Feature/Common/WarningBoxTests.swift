import XCTest
@testable import record_catch

final class WarningBoxTests: XCTestCase {

    func testAccessibilityLabel_composesTagAndMessage() {
        let label = WarningBox.accessibilityLabel(
            tag: "Important",
            message: "The Catch Records service will be available from 1 October 2026."
        )
        XCTAssertEqual(
            label,
            "Important, The Catch Records service will be available from 1 October 2026."
        )
    }

    func testAccessibilityLabel_welshTag() {
        let label = WarningBox.accessibilityLabel(tag: "Pwysig", message: "Neges")
        XCTAssertEqual(label, "Pwysig, Neges")
    }
}
