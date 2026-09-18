import XCTest
@testable import record_catch

final class TripDateValidationTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private let locale = Locale(identifier: "en_GB")

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Missing fields (priority: day > month > year)

    func test_departure_emptyValue_returnsDayMissing() {
        let result = TripDateValidation.result(
            for: DateEntryValue(),
            phase: .departure,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.departure.validation.day")
        XCTAssertEqual(result?.parts, [.day])
    }

    func test_departure_missingMonth_returnsMonthMissing() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "1", month: "", year: "2026"),
            phase: .departure,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.departure.validation.month")
        XCTAssertEqual(result?.parts, [.month])
    }

    func test_departure_missingYear_returnsYearMissing() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "1", month: "8", year: ""),
            phase: .departure,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.departure.validation.year")
        XCTAssertEqual(result?.parts, [.year])
    }

    func test_return_emptyValue_returnsDayMissing() {
        let result = TripDateValidation.result(
            for: DateEntryValue(),
            phase: .return,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.return.validation.day")
    }

    // MARK: - Not a real date

    func test_departure_invalidCalendarDate_returnsFormatError() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "31", month: "2", year: "2026"),
            phase: .departure,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.departure.validation.format")
        XCTAssertEqual(result?.parts, [])
    }

    func test_return_invalidCalendarDate_returnsFormatError() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "31", month: "2", year: "2026"),
            phase: .return,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.return.validation.format")
    }

    func test_departure_acceptsSingleDigitDayAndMonth() {
        // "3 8 2025" — the GOV.UK example format ("31 3 2019") uses unpadded day/month.
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "3", month: "8", year: "2025"),
            phase: .departure,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertNil(result)
    }

    // MARK: - Departure: minimum date (24 July 2025)

    func test_departure_beforeMinimumDate_returnsMinimumDateError() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "23", month: "7", year: "2025"),
            phase: .departure,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.departure.validation.minimumDate")
        XCTAssertEqual(result?.message.arguments, ["24 July 2025"])
    }

    func test_departure_exactlyMinimumDate_isValid() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "24", month: "7", year: "2025"),
            phase: .departure,
            departureDate: nil,
            now: date(2025, 7, 24),
            locale: locale
        )
        XCTAssertNil(result)
    }

    // MARK: - Departure: today or in the past

    func test_departure_futureDate_returnsFutureError() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "2", month: "1", year: "2026"),
            phase: .departure,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.departure.validation.future")
    }

    func test_departure_exactlyToday_isValid() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "1", month: "1", year: "2026"),
            phase: .departure,
            departureDate: nil,
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertNil(result)
    }

    // MARK: - Return: today or in the past, then on/after departure

    func test_return_futureDate_returnsFutureError() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "2", month: "1", year: "2026"),
            phase: .return,
            departureDate: date(2025, 12, 1),
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.return.validation.future")
    }

    func test_return_beforeDeparture_returnsBeforeDepartureError() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "1", month: "8", year: "2025"),
            phase: .return,
            departureDate: date(2025, 8, 2),
            now: date(2026, 1, 1),
            locale: locale
        )
        XCTAssertEqual(result?.message.key, "catchRecord.tripDate.return.validation.beforeDeparture")
    }

    func test_return_sameDayAsDeparture_isValid() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "2", month: "8", year: "2025"),
            phase: .return,
            departureDate: date(2025, 8, 2),
            now: date(2025, 8, 2),
            locale: locale
        )
        XCTAssertNil(result)
    }

    func test_return_afterDeparture_isValid() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "3", month: "8", year: "2025"),
            phase: .return,
            departureDate: date(2025, 8, 2),
            now: date(2025, 8, 3),
            locale: locale
        )
        XCTAssertNil(result)
    }

    func test_return_withNoDepartureDate_skipsBeforeDepartureCheck() {
        let result = TripDateValidation.result(
            for: DateEntryValue(day: "1", month: "8", year: "2025"),
            phase: .return,
            departureDate: nil,
            now: date(2025, 8, 1),
            locale: locale
        )
        XCTAssertNil(result)
    }
}
