import XCTest
@testable import record_catch

final class CatchLocationValidationTests: XCTestCase {

    func test_errorKey_whenNil_returnsValidationKey() {
        XCTAssertEqual(
            CatchLocationValidation.errorKey(for: nil),
            "catchRecord.catchLocation.validation.none"
        )
    }

    func test_errorKey_whenEmpty_returnsValidationKey() {
        XCTAssertEqual(
            CatchLocationValidation.errorKey(for: ""),
            "catchRecord.catchLocation.validation.none"
        )
    }

    func test_errorKey_whenAreaSelected_isNil() {
        XCTAssertNil(CatchLocationValidation.errorKey(for: "38E96"))
    }
}
