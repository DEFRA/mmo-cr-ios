import XCTest
@testable import record_catch

final class AddPortValidationTests: XCTestCase {

    func test_errorKey_withNoSelection_returnsValidationKey() {
        XCTAssertEqual(AddPortValidation.errorKey(for: nil), "catchRecord.addPort.validation.none")
    }

    func test_errorKey_withSelection_returnsNil() {
        XCTAssertNil(AddPortValidation.errorKey(for: PortOption(name: "Hastings")))
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
