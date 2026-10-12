import XCTest
@testable import record_catch

final class CatchLocationManualEntryValidationTests: XCTestCase {

    func test_message_whenQueryBlank_asksUserToEnter() {
        XCTAssertEqual(
            CatchLocationManualEntryValidation.message(query: "", selectedCode: nil),
            ValidationMessage("catchRecord.manualEntry.validation.enter")
        )
    }

    func test_message_whenWhitespaceOnly_treatedAsBlank() {
        XCTAssertEqual(
            CatchLocationManualEntryValidation.message(query: "   ", selectedCode: nil),
            ValidationMessage("catchRecord.manualEntry.validation.enter")
        )
    }

    func test_message_whenTypedButNothingSelected_asksUserToSelectFromList() {
        XCTAssertEqual(
            CatchLocationManualEntryValidation.message(query: "27D8", selectedCode: nil),
            ValidationMessage("catchRecord.manualEntry.validation.select")
        )
    }

    func test_message_withValidSelection_isNil() {
        XCTAssertNil(
            CatchLocationManualEntryValidation.message(query: "27D86", selectedCode: "27D86")
        )
    }
}
