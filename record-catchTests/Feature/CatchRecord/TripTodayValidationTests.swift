import XCTest
@testable import record_catch

final class TripTodayValidationTests: XCTestCase {

    func test_errorKey_noSelection_returnsValidationKey() {
        XCTAssertEqual(
            TripTodayValidation.errorKey(for: nil),
            "catchRecord.tripToday.validation.none"
        )
    }

    func test_errorKey_yesSelected_returnsNil() {
        XCTAssertNil(TripTodayValidation.errorKey(for: .yes))
    }

    func test_errorKey_noSelected_returnsNil() {
        XCTAssertNil(TripTodayValidation.errorKey(for: .no))
    }
}
