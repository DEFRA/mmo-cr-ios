import Foundation

/// View model for the reusable trip-date screen (departure and return variants).
///
/// UI only — no persistence or networking. On a valid departure date it pushes the return
/// variant carrying the parsed departure date; on a valid return date it continues to the next
/// step. See ADR-0003 for the routing pattern.
///
/// Uses a native `DatePicker` (see `TripDatePicker`, ADR-0017) rather than the day/month/year
/// `DateEntryField` this screen used previously. Because `selectedDate` is always a concrete
/// `Date`, defaulted to today, and `selectableRange` clamps out every date the business rules
/// forbid (including the service's earliest supported trip date — see `CatchRecordDateRules`),
/// there is no "missing field"/"not a real date" validation step left to run here.
@MainActor
@Observable
final class TripDateViewModel {

    /// Which date this screen is collecting; drives copy, identifiers and the next route.
    let phase: TripDatePhase
    /// Selected vessel name, threaded onward for the port screens' headers.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String
    /// The parsed departure date carried into the return screen (nil for the departure screen).
    let departureDate: Date?

    /// The date currently selected in the picker. Defaults to today (or the resumed draft's
    /// already-captured date — see ADR-0015 decision #1), clamped into `selectableRange`.
    var selectedDate: Date

    /// The inclusive range of calendar days the picker allows.
    ///
    /// - Departure: on or after the service's earliest supported trip date
    ///   (`CatchRecordDateRules.earliestTripDate`), up to and including today.
    /// - Return: on or after the departure date, and no later than today.
    ///
    /// Computed once at `init` from the injected `now`, so the screen's bounds stay stable for
    /// the lifetime of a single visit (deterministic for tests; a real device crossing midnight
    /// mid-visit simply keeps the bound it started with).
    let selectableRange: ClosedRange<Date>

    private let router: CatchRecordRouter
    private let favouritePorts: FavouritePortsProviding
    /// Shared journey draft; the parsed date is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft
    /// Injectable "now" so the late-submission nudge decision is deterministic in tests.
    private let now: () -> Date
    private let calendar = Calendar(identifier: .gregorian)

    init(
        phase: TripDatePhase,
        vessel: String,
        referenceNumber: String,
        departureDate: Date?,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider(),
        draft: CatchRecordDraft = CatchRecordDraft(),
        now: @escaping () -> Date = Date.init
    ) {
        self.phase = phase
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.departureDate = departureDate
        self.router = router
        self.favouritePorts = favouritePorts
        self.draft = draft
        self.now = now

        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now())
        let range = Self.selectableRange(phase: phase, departureDate: departureDate, today: today, calendar: calendar)
        self.selectableRange = range

        // Pre-fills the previously-captured date when restarting a resumed draft from the
        // beginning (see ADR-0015 decision #1). Clamped defensively in case an older/corrupt
        // draft holds a date outside today's computed range.
        let existing: Date?
        switch phase {
        case .departure:
            existing = draft.departureDate
        case .return:
            existing = draft.returnDate
        }
        if let existing {
            let day = calendar.startOfDay(for: existing)
            self.selectedDate = min(max(day, range.lowerBound), range.upperBound)
        } else {
            self.selectedDate = today
        }
    }

    /// String Catalog key for the screen's H1.
    var titleKey: String { phase.titleKey }

    /// String Catalog key for the screen's hint.
    var hintKey: String { phase.hintKey }

    /// The allowed date range for this phase, given `today` and (for the return phase) the
    /// departure date. A defensive `min(lower, today)` keeps the range non-inverted (a
    /// `ClosedRange` with `lowerBound > upperBound` traps at runtime) even if an older/corrupt
    /// draft's departure date is after today, or before the service's earliest supported date.
    private static func selectableRange(
        phase: TripDatePhase,
        departureDate: Date?,
        today: Date,
        calendar: Calendar
    ) -> ClosedRange<Date> {
        switch phase {
        case .departure:
            let earliest = calendar.startOfDay(for: CatchRecordDateRules.earliestTripDate)
            return min(earliest, today)...today
        case .return:
            let lower = departureDate.map { calendar.startOfDay(for: $0) } ?? Date.distantPast
            return min(lower, today)...today
        }
    }

    /// Persists the selected date and routes onward. The picker's `range` makes every entered
    /// date valid by construction, so there is nothing left to validate before routing.
    ///
    /// When reached via "Change" from Check your answers (`draft.returnToCheckYourAnswers`), only
    /// this one date is being corrected, so the journey returns straight there instead of
    /// continuing into the other date/late-submission-nudge/port screens (see ADR-0013).
    func submit() {
        let date = calendar.startOfDay(for: selectedDate)
        switch phase {
        case .departure:
            draft.departureDate = date
        case .return:
            draft.returnDate = date
        }

        if draft.returnToCheckYourAnswers {
            draft.returnToCheckYourAnswers = false
            router.push(.checkYourAnswers(referenceNumber: referenceNumber))
            return
        }

        switch phase {
        case .departure:
            router.push(.tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: date))
        case .return:
            // Records must be submitted within 24 hours of a trip ending. When the trip ended more
            // than 24 hours ago, interpose the late-submission nudge before the port sub-journey so
            // the user can double-check the trip end date (see `SubmissionNudge`).
            let currentTime = now()
            if SubmissionNudge.isNeeded(tripEndDate: date, now: currentTime) {
                let daysLate = SubmissionNudge.daysLate(tripEndDate: date, now: currentTime)
                router.push(.submissionNudge(daysLate: daysLate, vessel: vessel, referenceNumber: referenceNumber))
            } else {
                Task { await enterPortSubJourney() }
            }
        }
    }

    /// Fetches favourites, then pushes the pure port-entry route (Add port vs Select departure).
    func enterPortSubJourney() async {
        let favourites = (try? await favouritePorts.favouritePorts()) ?? []
        router.push(CatchRecordRouting.portEntryRoute(
            hasFavourites: !favourites.isEmpty,
            vessel: vessel,
            referenceNumber: referenceNumber
        ))
    }
}
