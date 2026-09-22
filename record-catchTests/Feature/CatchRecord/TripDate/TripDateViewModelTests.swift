import XCTest
@testable import record_catch

@MainActor
final class TripDateViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: - Initial state (default to today — see plan Q2)

    func test_initialState_defaultsSelectedDateToToday_andExposesPhaseCopy() {
        let today = date(2026, 4, 3)
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            now: { today }
        )
        XCTAssertEqual(sut.selectedDate, today)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
        XCTAssertEqual(sut.vessel, vessel)
        XCTAssertEqual(sut.titleKey, "catchRecord.tripDate.departure.title")
        XCTAssertEqual(sut.hintKey, "catchRecord.tripDate.departure.hint")
    }

    func test_returnPhase_exposesReturnCopy() {
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: CatchRecordRouter()
        )
        XCTAssertEqual(sut.titleKey, "catchRecord.tripDate.return.title")
        XCTAssertEqual(sut.hintKey, "catchRecord.tripDate.return.hint")
    }

    // MARK: - Selectable range (see plan §3 Q3 — range-constrained rather than validated)

    /// The departure lower bound is the service's earliest supported trip date (see
    /// `CatchRecordDateRules.earliestTripDate`), not `Date.distantPast`.
    func test_selectableRange_departure_isEarliestTripDateThroughToday() {
        let today = date(2026, 4, 3)
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            now: { today }
        )
        XCTAssertEqual(sut.selectableRange.upperBound, today)
        XCTAssertEqual(sut.selectableRange.lowerBound, calendar.startOfDay(for: CatchRecordDateRules.earliestTripDate))
    }

    /// If "today" ever fell before the earliest supported trip date, the range must not invert.
    func test_selectableRange_departure_whenTodayBeforeEarliestTripDate_clampsToNonInvertedRange() {
        let today = date(2025, 1, 1)
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            now: { today }
        )
        XCTAssertEqual(sut.selectableRange.lowerBound, today)
        XCTAssertEqual(sut.selectableRange.upperBound, today)
    }

    func test_selectableRange_return_isDepartureDateThroughToday() {
        let today = date(2026, 4, 3)
        let departure = date(2026, 3, 31)
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: departure,
            router: CatchRecordRouter(),
            now: { today }
        )
        XCTAssertEqual(sut.selectableRange.lowerBound, departure)
        XCTAssertEqual(sut.selectableRange.upperBound, today)
    }

    /// A corrupt/older draft's departure date could in theory be after "today". The range must
    /// never invert (a `ClosedRange` with `lowerBound > upperBound` traps at runtime).
    func test_selectableRange_return_withDepartureDateAfterToday_clampsToNonInvertedRange() {
        let today = date(2026, 4, 3)
        let futureDeparture = date(2026, 4, 10)
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: futureDeparture,
            router: CatchRecordRouter(),
            now: { today }
        )
        XCTAssertEqual(sut.selectableRange.lowerBound, today)
        XCTAssertEqual(sut.selectableRange.upperBound, today)
    }

    // MARK: - Submit: departure success

    func test_submit_departure_pushesReturnCarryingDepartureDate() {
        let router = CatchRecordRouter()
        let today = date(2026, 4, 3)
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: router,
            now: { today }
        )

        sut.submit()

        XCTAssertEqual(
            router.path,
            [.tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: today)]
        )
    }

    /// `DatePicker` returns a `Date` carrying the current time of day; the persisted date must be
    /// normalised to midnight so `SubmissionNudge`'s 24-hour comparison (a raw `timeIntervalSince`)
    /// isn't silently thrown off by whatever time of day the user happened to submit at.
    func test_submit_normalisesSelectedDateToStartOfDay_regardlessOfTimeOfDaySelected() {
        let draft = CatchRecordDraft()
        let router = CatchRecordRouter()
        let today = date(2026, 4, 3)
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: router,
            draft: draft,
            now: { today }
        )
        sut.selectedDate = date(2026, 4, 3, hour: 17)

        sut.submit()

        XCTAssertEqual(draft.departureDate, calendar.startOfDay(for: date(2026, 4, 3, hour: 17)))
    }

    // MARK: - Submit: return success (enters port sub-journey)

    func test_enterPortSubJourney_return_withNoFavourites_pushesAddPort() async {
        let router = CatchRecordRouter()
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: router,
            favouritePorts: StubFavouritePortsProvider()
        )

        await sut.enterPortSubJourney()

        XCTAssertEqual(
            router.path,
            [.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: nil)]
        )
    }

    func test_enterPortSubJourney_return_withFavourites_pushesSelectDeparture() async {
        let router = CatchRecordRouter()
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: router,
            favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
        )

        await sut.enterPortSubJourney()

        XCTAssertEqual(
            router.path,
            [.selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    // MARK: - Submit: return date late-submission nudge

    func test_submit_return_whenTripEndedMoreThan24HoursAgo_pushesSubmissionNudge() {
        let router = CatchRecordRouter()
        let returnDate = date(2026, 3, 31)
        // "now" is many days later, so the nudge is required.
        let now = date(2026, 4, 3, hour: 12)
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: date(2026, 3, 30),
            router: router,
            now: { now }
        )
        sut.selectedDate = returnDate

        sut.submit()

        XCTAssertEqual(
            router.path,
            [.submissionNudge(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_return_whenWithin24Hours_doesNotPushNudge() {
        let router = CatchRecordRouter()
        let returnDate = date(2026, 3, 31)
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: date(2026, 3, 30),
            router: router,
            favouritePorts: StubFavouritePortsProvider(),
            // "now" is 1 hour after the entered return date's midnight, so no nudge is
            // interposed. The port sub-journey is exercised deterministically by the
            // `enterPortSubJourney` tests above; here we assert only that no `submissionNudge`
            // route is pushed synchronously.
            now: { returnDate.addingTimeInterval(60 * 60) }
        )
        sut.selectedDate = returnDate

        sut.submit()

        XCTAssertFalse(router.path.contains(.submissionNudge(daysLate: 0, vessel: vessel, referenceNumber: referenceNumber)))
    }

    // MARK: - Draft capture

    func test_submit_departure_writesDepartureDateIntoDraft() {
        let draft = CatchRecordDraft()
        let today = date(2026, 4, 3)
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: draft,
            now: { today }
        )

        sut.submit()

        XCTAssertEqual(draft.departureDate, today)
        XCTAssertNil(draft.returnDate)
    }

    func test_submit_return_writesReturnDateIntoDraft() {
        let draft = CatchRecordDraft()
        let returnDate = date(2026, 3, 31)
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: date(2026, 3, 30),
            router: CatchRecordRouter(),
            draft: draft,
            now: { returnDate.addingTimeInterval(60 * 60) }
        )
        sut.selectedDate = returnDate

        sut.submit()

        XCTAssertEqual(draft.returnDate, returnDate)
    }

    // MARK: - Resume at Check your answers (see ADR-0013)

    func test_submit_departure_whenResumingAtCheckYourAnswers_pushesCheckYourAnswers_insteadOfReturnPhase() {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.returnToCheckYourAnswers = true
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: router,
            draft: draft
        )

        sut.submit()

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswers)
    }

    func test_submit_return_whenResumingAtCheckYourAnswers_pushesCheckYourAnswers_insteadOfNudgeOrPorts() {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.returnToCheckYourAnswers = true
        let returnDate = date(2026, 3, 31)
        // "now" is far past the entered return date, so a nudge would otherwise be interposed —
        // resuming at Check your answers must still take priority.
        let now = date(2026, 4, 3, hour: 12)
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: date(2026, 3, 30),
            router: router,
            draft: draft,
            now: { now }
        )
        sut.selectedDate = returnDate

        sut.submit()

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswers)
    }

    // MARK: - Pre-fill on resume (see ADR-0015 decision #1)

    func test_init_departure_prefillsSelectedDateFromDraftDepartureDate() {
        let draft = CatchRecordDraft()
        draft.departureDate = date(2026, 3, 31)

        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: draft,
            now: { self.date(2026, 4, 3) }
        )

        XCTAssertEqual(sut.selectedDate, date(2026, 3, 31))
    }

    func test_init_return_prefillsSelectedDateFromDraftReturnDate() {
        let draft = CatchRecordDraft()
        draft.returnDate = date(2026, 4, 2)

        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: date(2026, 3, 30),
            router: CatchRecordRouter(),
            draft: draft,
            now: { self.date(2026, 4, 3) }
        )

        XCTAssertEqual(sut.selectedDate, date(2026, 4, 2))
    }

    func test_init_withNoDraftDate_defaultsSelectedDateToToday() {
        let today = date(2026, 4, 3)
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: CatchRecordDraft(),
            now: { today }
        )

        XCTAssertEqual(sut.selectedDate, today)
    }

    /// A resumed draft's date that falls outside today's computed range (e.g. an older draft's
    /// departure date now reads as "in the future" relative to a later resume) must be clamped
    /// into the range rather than left invalid for the picker.
    func test_init_return_withDraftDateBeforeDepartureDate_clampsSelectedDateUpToDeparture() {
        let draft = CatchRecordDraft()
        draft.returnDate = date(2026, 3, 20)

        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: date(2026, 3, 30),
            router: CatchRecordRouter(),
            draft: draft,
            now: { self.date(2026, 4, 3) }
        )

        XCTAssertEqual(sut.selectedDate, date(2026, 3, 30))
    }
}
