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
}
