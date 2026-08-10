import XCTest
@testable import record_catch

final class TripDateValidationTests: XCTestCase {

    func test_errorKey_realDate_returnsNil() {
        let value = DateEntryValue(day: "31", month: "03", year: "2020")
        XCTAssertNil(TripDateValidation.errorKey(for: value))
    }

    func test_errorKey_invalidCalendarDate_returnsValidationKey() {
        let value = DateEntryValue(day: "31", month: "02", year: "2020")
        XCTAssertEqual(
            TripDateValidation.errorKey(for: value),
            "catchRecord.tripDate.validation.none"
        )
    }

    func test_errorKey_emptyValue_returnsValidationKey() {
        XCTAssertEqual(
            TripDateValidation.errorKey(for: DateEntryValue()),
            "catchRecord.tripDate.validation.none"
        )
    }

    func test_errorKey_partialValue_returnsValidationKey() {
        let value = DateEntryValue(day: "1", month: "3", year: "20")
        XCTAssertEqual(
            TripDateValidation.errorKey(for: value),
            "catchRecord.tripDate.validation.none"
        )
    }

    func test_errorKey_nonNumericValue_returnsValidationKey() {
        let value = DateEntryValue(day: "aa", month: "bb", year: "cccc")
        XCTAssertEqual(
            TripDateValidation.errorKey(for: value),
            "catchRecord.tripDate.validation.none"
        )
    }
}
