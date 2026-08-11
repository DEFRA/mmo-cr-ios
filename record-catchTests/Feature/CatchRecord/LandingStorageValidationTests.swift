import XCTest
@testable import record_catch

final class LandingStorageValidationTests: XCTestCase {

    func test_errorKey_noSelection_returnsValidationKey() {
        XCTAssertEqual(
            LandingStorageValidation.errorKey(for: nil),
            "catchRecord.landingStorage.validation.none"
        )
    }

    func test_errorKey_yesSelected_returnsNil() {
        XCTAssertNil(LandingStorageValidation.errorKey(for: .yes))
    }

    func test_errorKey_noSelected_returnsNil() {
        XCTAssertNil(LandingStorageValidation.errorKey(for: .no))
    }
}
