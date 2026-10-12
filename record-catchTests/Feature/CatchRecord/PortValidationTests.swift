import XCTest
@testable import record_catch

final class AddPortValidationTests: XCTestCase {

    func test_message_whenQueryBlank_asksUserToEnter() {
        XCTAssertEqual(
            AddPortValidation.message(query: "", selectedPort: nil),
            ValidationMessage("catchRecord.addPort.validation.enter")
        )
    }

    func test_message_whenWhitespaceOnly_treatedAsBlank() {
        XCTAssertEqual(
            AddPortValidation.message(query: "   ", selectedPort: nil),
            ValidationMessage("catchRecord.addPort.validation.enter")
        )
    }

    func test_message_whenTypedButNothingSelected_asksUserToSelectFromList() {
        XCTAssertEqual(
            AddPortValidation.message(query: "Hast", selectedPort: nil),
            ValidationMessage("catchRecord.addPort.validation.none")
        )
    }

    func test_message_withValidSelection_isNil() {
        XCTAssertNil(
            AddPortValidation.message(query: "Hastings", selectedPort: PortOption(name: "Hastings"))
        )
    }
}

final class SelectPortValidationTests: XCTestCase {

    func test_departure_withNoSelection_returnsDepartureKey() {
        XCTAssertEqual(
            SelectPortValidation.errorKey(for: nil, phase: .departure),
            "catchRecord.selectPort.departure.validation.none"
        )
    }

    func test_return_withNoSelection_returnsReturnKey() {
        XCTAssertEqual(
            SelectPortValidation.errorKey(for: nil, phase: .return),
            "catchRecord.selectPort.return.validation.none"
        )
    }

    func test_withSelection_returnsNil_forBothPhases() {
        XCTAssertNil(SelectPortValidation.errorKey(for: "Hastings", phase: .departure))
        XCTAssertNil(SelectPortValidation.errorKey(for: "Hastings", phase: .return))
    }
}

final class ConfirmSamePortValidationTests: XCTestCase {

    func test_errorKey_withNoSelection_returnsValidationKey() {
        XCTAssertEqual(
            ConfirmSamePortValidation.errorKey(for: nil),
            "catchRecord.confirmSamePort.validation.none"
        )
    }

    func test_errorKey_withSelection_returnsNil_forBothOptions() {
        XCTAssertNil(ConfirmSamePortValidation.errorKey(for: .yes))
        XCTAssertNil(ConfirmSamePortValidation.errorKey(for: .no))
    }
}
