import XCTest
@testable import record_catch

final class DateEntryFieldTests: XCTestCase {

    func testParsedDateReturnsDateForValidInput() {
        let value = DateEntryValue(day: "31", month: "03", year: "2026")

        let parsed = DateEntryField.parsedDate(from: value)

        XCTAssertNotNil(parsed)
    }

    func testParsedDateReturnsNilForInvalidCalendarDate() {
        let value = DateEntryValue(day: "31", month: "02", year: "2026")

        XCTAssertNil(DateEntryField.parsedDate(from: value))
    }

    func testParsedDateReturnsNilForNonLeapYearFebruary29() {
        let value = DateEntryValue(day: "29", month: "02", year: "2023")

        XCTAssertNil(DateEntryField.parsedDate(from: value))
    }

    func testParsedDateReturnsDateForLeapYearFebruary29() {
        let value = DateEntryValue(day: "29", month: "02", year: "2024")

        XCTAssertNotNil(DateEntryField.parsedDate(from: value))
    }

    func testParsedDateReturnsNilWhenFieldsAreWrongLength() {
        let value = DateEntryValue(day: "1", month: "3", year: "2026")

        XCTAssertNil(DateEntryField.parsedDate(from: value))
    }
}
