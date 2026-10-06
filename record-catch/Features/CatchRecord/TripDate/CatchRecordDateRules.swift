import Foundation

/// Business-rule constants and helpers for the trip-date screens (`TripDateValidation`).
enum CatchRecordDateRules {

    /// The earliest trip departure date the service currently supports.
    ///
    /// **Provisional**: confirmed as a placeholder ("dummy") value for this phase rather than a
    /// value driven by real service launch data — kept as a single constant so it is trivial to
    /// change later without touching the validation logic itself (see plan Q4).
    static let earliestTripDate: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 7
        components.day = 24
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    /// The service's rolling historical limit (BR-CAT-006/AC02): a trip start date may not be
    /// entered more than this many days before "today".
    static let maximumTripAgeInDays = 365

    /// The earliest trip departure date currently selectable, given `now`: the later of the
    /// service's launch floor (`earliestTripDate`) and the rolling `maximumTripAgeInDays` window.
    ///
    /// Both bounds apply together — the rolling window only becomes the binding constraint once
    /// it has moved past the (provisional) launch floor.
    static func earliestSelectableTripDate(now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let rollingFloor = calendar.date(byAdding: .day, value: -maximumTripAgeInDays, to: today) ?? .distantPast
        return max(calendar.startOfDay(for: earliestTripDate), rollingFloor)
    }

    /// Formats `date` as a long, localised date (e.g. "24 July 2025" / "24 Gorffennaf 2025") for
    /// interpolation into a validation message.
    static func longDateString(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Whether `date` falls on or before the start of "today" in `calendar` — i.e. today or in the
    /// past, ignoring time-of-day so a departure/return entered as "today" always passes even if
    /// the current time has since moved on.
    static func isTodayOrInThePast(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        return date < startOfTomorrow
    }
}
