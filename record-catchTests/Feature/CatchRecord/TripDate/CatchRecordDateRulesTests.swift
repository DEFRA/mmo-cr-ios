import XCTest
@testable import record_catch

final class CatchRecordDateRulesTests: XCTestCase {

    func test_earliestTripDate_is24July2025() {
        let components = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day], from: CatchRecordDateRules.earliestTripDate)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 24)
    }

    func test_longDateString_englishLocale_formatsAsExpected() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2025, month: 7, day: 24))!
        XCTAssertEqual(CatchRecordDateRules.longDateString(date, locale: Locale(identifier: "en_GB")), "24 July 2025")
    }

    func test_isTodayOrInThePast_today_isTrue() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 23, minute: 59))!
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        XCTAssertTrue(CatchRecordDateRules.isTodayOrInThePast(date, now: now, calendar: calendar))
    }

    func test_isTodayOrInThePast_tomorrow_isFalse() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        XCTAssertFalse(CatchRecordDateRules.isTodayOrInThePast(date, now: now, calendar: calendar))
    }

    func test_isTodayOrInThePast_yesterday_isTrue() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        XCTAssertTrue(CatchRecordDateRules.isTodayOrInThePast(date, now: now, calendar: calendar))
    }

    // MARK: - earliestSelectableTripDate (BR-CAT-006/AC02 — rolling 365-day limit)

    func test_maximumTripAgeInDays_is365() {
        XCTAssertEqual(CatchRecordDateRules.maximumTripAgeInDays, 365)
    }

    /// Once "today" has moved far enough past the service's launch floor, the rolling 365-day
    /// window becomes the binding constraint rather than the fixed launch date.
    func test_earliestSelectableTripDate_whenRollingWindowIsLaterThanLaunchFloor_usesRollingWindow() {
        let calendar = Calendar(identifier: .gregorian)
        // 24 July 2025 + 365 days + a further 100 days, so "365 days before now" is unambiguously
        // after the launch floor.
        let now = calendar.date(byAdding: .day, value: 465, to: CatchRecordDateRules.earliestTripDate)!

        let earliest = CatchRecordDateRules.earliestSelectableTripDate(now: now, calendar: calendar)

        let expected = calendar.date(byAdding: .day, value: -365, to: calendar.startOfDay(for: now))!
        XCTAssertEqual(earliest, expected)
        XCTAssertGreaterThan(earliest, calendar.startOfDay(for: CatchRecordDateRules.earliestTripDate))
    }

    /// While "today" is still close to the service's launch, the rolling window would reach
    /// further back than the launch floor — the launch floor must still win (the two bounds
    /// combine via "the later of the two").
    func test_earliestSelectableTripDate_whenRollingWindowIsEarlierThanLaunchFloor_usesLaunchFloor() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(byAdding: .day, value: 10, to: CatchRecordDateRules.earliestTripDate)!

        let earliest = CatchRecordDateRules.earliestSelectableTripDate(now: now, calendar: calendar)

        XCTAssertEqual(earliest, calendar.startOfDay(for: CatchRecordDateRules.earliestTripDate))
    }

    /// Boundary: exactly 365 days ago is still selectable (the limit is "no more than 365 days").
    func test_earliestSelectableTripDate_exactly365DaysBack_isSelectable() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(byAdding: .day, value: 500, to: CatchRecordDateRules.earliestTripDate)!
        let earliest = CatchRecordDateRules.earliestSelectableTripDate(now: now, calendar: calendar)

        let exactly365DaysBack = calendar.date(byAdding: .day, value: -365, to: calendar.startOfDay(for: now))!
        XCTAssertEqual(earliest, exactly365DaysBack)
    }
}
