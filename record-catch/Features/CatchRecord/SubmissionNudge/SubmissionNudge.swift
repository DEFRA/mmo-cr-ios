import Foundation

/// Pure decision logic for the "late submission" nudge.
///
/// Catch records must be submitted within 24 hours of a trip ending. When the entered trip end
/// (return) date is more than 24 hours before "now", the journey interposes a nudge screen that
/// asks the user to double-check the trip end date before continuing. Kept out of the view
/// model/view so the rule is trivially unit-testable with a controllable clock (no view host,
/// no wall-clock flakiness).
enum SubmissionNudge {

    /// The submission window: records must be submitted within 24 hours of the trip ending.
    static let submissionWindow: TimeInterval = 24 * 60 * 60

    /// Whether the nudge should be shown for a trip that ended at `tripEndDate`.
    ///
    /// `true` when the trip ended more than 24 hours before `now`. A future trip end date, or one
    /// within the last 24 hours, does not trigger the nudge.
    static func isNeeded(tripEndDate: Date, now: Date) -> Bool {
        now.timeIntervalSince(tripEndDate) > submissionWindow
    }

    /// Whole days between the trip end date and `now`, floored and never negative.
    ///
    /// Drives the "…submitted x days after the trip end date" heading. Uses calendar-day
    /// boundaries so a trip that ended "2 days ago" reads naturally regardless of the time of day.
    static func daysLate(tripEndDate: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        let startOfEnd = calendar.startOfDay(for: tripEndDate)
        let startOfNow = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: startOfEnd, to: startOfNow).day ?? 0
        return max(0, days)
    }
}
