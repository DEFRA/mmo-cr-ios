import XCTest
@testable import record_catch

final class SubmissionNudgeTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = hour
        return calendar.date(from: c)!
    }

    // MARK: - isNeeded

    func test_isNeeded_whenTripEndedMoreThan24HoursAgo_isTrue() {
        let end = date(2026, 8, 8)
        let now = end.addingTimeInterval(SubmissionNudge.submissionWindow + 1)
        XCTAssertTrue(SubmissionNudge.isNeeded(tripEndDate: end, now: now))
    }

    func test_isNeeded_whenExactly24HoursAgo_isFalse() {
        let end = date(2026, 8, 8)
        let now = end.addingTimeInterval(SubmissionNudge.submissionWindow)
        XCTAssertFalse(SubmissionNudge.isNeeded(tripEndDate: end, now: now))
    }

    func test_isNeeded_whenWithin24Hours_isFalse() {
        let end = date(2026, 8, 8)
        let now = end.addingTimeInterval(60 * 60)
        XCTAssertFalse(SubmissionNudge.isNeeded(tripEndDate: end, now: now))
    }

    func test_isNeeded_whenTripEndIsInTheFuture_isFalse() {
        let end = date(2026, 8, 10)
        let now = date(2026, 8, 8)
        XCTAssertFalse(SubmissionNudge.isNeeded(tripEndDate: end, now: now))
    }

    // MARK: - daysLate

    func test_daysLate_countsWholeCalendarDays() {
        let end = date(2026, 8, 5)
        let now = date(2026, 8, 8)
        XCTAssertEqual(SubmissionNudge.daysLate(tripEndDate: end, now: now, calendar: calendar), 3)
    }

    func test_daysLate_ignoresTimeOfDay() {
        let end = date(2026, 8, 7, hour: 23)
        let now = date(2026, 8, 8, hour: 1)
        XCTAssertEqual(SubmissionNudge.daysLate(tripEndDate: end, now: now, calendar: calendar), 1)
    }

    func test_daysLate_neverNegative_forFutureTripEnd() {
        let end = date(2026, 8, 10)
        let now = date(2026, 8, 8)
        XCTAssertEqual(SubmissionNudge.daysLate(tripEndDate: end, now: now, calendar: calendar), 0)
    }
}
