import XCTest
@testable import record_catch

@MainActor
final class TripDateViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"
    private let locale = Locale(identifier: "en_GB")

    private func makeValidDate() -> DateEntryValue {
        DateEntryValue(day: "31", month: "03", year: "2026")
    }

    /// A fixed departure date before `makeValidDate()`'s 31/03/2026 return date, for return-phase
    /// tests that must satisfy the "return must be on or after departure" rule. Using `Date()` here
    /// would fail non-deterministically once the current date passes the fixed return date.
    private var earlyDepartureDate: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 1))!
    }

    // MARK: - Initial state

    func test_initialState_hasNoErrorAndExposesPhaseCopy() {
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter()
        )
        XCTAssertNil(sut.validationResult(locale: locale))
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

    // MARK: - Submit: failure

    func test_submit_withInvalidDate_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: router
        )

        sut.submit(locale: locale)

        XCTAssertEqual(sut.validationResult(locale: locale)?.message.key, "catchRecord.tripDate.departure.validation.day")
        XCTAssertTrue(router.path.isEmpty)
    }

    // MARK: - Submit: departure success

    func test_submit_departure_withValidDate_pushesReturnCarryingDepartureDate() {
        let router = CatchRecordRouter()
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: router
        )
        sut.value = makeValidDate()

        sut.submit(locale: locale)

        XCTAssertNil(sut.validationResult(locale: locale))
        let expectedDate = DateEntryField.parsedDate(from: makeValidDate())
        XCTAssertEqual(
            router.path,
            [.tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: expectedDate)]
        )
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

    func test_validationResult_beforeSubmit_isNil() {
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter()
        )
        sut.value = DateEntryValue()
        XCTAssertNil(sut.validationResult(locale: locale))
    }

    // MARK: - Submit: return date late-submission nudge

    func test_submit_return_whenTripEndedMoreThan24HoursAgo_pushesSubmissionNudge() {
        let router = CatchRecordRouter()
        // Return date 31/03/2026; "now" is many days later, so the nudge is required.
        let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: 3, hour: 12))!
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: earlyDepartureDate,
            router: router,
            now: { now }
        )
        sut.value = makeValidDate()

        sut.submit(locale: locale)

        XCTAssertNil(sut.validationResult(locale: locale))
        XCTAssertEqual(
            router.path,
            [.submissionNudge(daysLate: 3, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_return_whenWithin24Hours_doesNotPushNudge() {
        let router = CatchRecordRouter()
        // "now" is 1 hour after the entered return date, so no nudge is interposed. The port
        // sub-journey is exercised deterministically by the `enterPortSubJourney` tests above;
        // here we assert only that no `submissionNudge` route is pushed synchronously.
        let end = DateEntryField.parsedDate(from: makeValidDate())!
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: earlyDepartureDate,
            router: router,
            favouritePorts: StubFavouritePortsProvider(),
            now: { end.addingTimeInterval(60 * 60) }
        )
        sut.value = makeValidDate()

        sut.submit(locale: locale)

        XCTAssertNil(sut.validationResult(locale: locale))
        XCTAssertFalse(router.path.contains(.submissionNudge(daysLate: 0, vessel: vessel, referenceNumber: referenceNumber)))
    }

    // MARK: - Draft capture

    func test_submit_departure_withValidDate_writesDepartureDateIntoDraft() {
        let draft = CatchRecordDraft()
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: draft
        )
        sut.value = makeValidDate()

        sut.submit(locale: locale)

        XCTAssertEqual(draft.departureDate, DateEntryField.parsedDate(from: makeValidDate()))
        XCTAssertNil(draft.returnDate)
    }

    func test_submit_return_withValidDate_writesReturnDateIntoDraft() {
        let draft = CatchRecordDraft()
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: earlyDepartureDate,
            router: CatchRecordRouter(),
            draft: draft,
            now: { DateEntryField.parsedDate(from: self.makeValidDate())!.addingTimeInterval(60 * 60) }
        )
        sut.value = makeValidDate()

        sut.submit(locale: locale)

        XCTAssertEqual(draft.returnDate, DateEntryField.parsedDate(from: makeValidDate()))
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
        sut.value = makeValidDate()

        sut.submit(locale: locale)

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswers)
    }

    func test_submit_return_whenResumingAtCheckYourAnswers_pushesCheckYourAnswers_insteadOfNudgeOrPorts() {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.returnToCheckYourAnswers = true
        // "now" is far past the entered return date, so a nudge would otherwise be interposed —
        // resuming at Check your answers must still take priority.
        let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: 3, hour: 12))!
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: earlyDepartureDate,
            router: router,
            draft: draft,
            now: { now }
        )
        sut.value = makeValidDate()

        sut.submit(locale: locale)

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswers)
    }

    // MARK: - Pre-fill on resume (see ADR-0015 decision #1)

    func test_init_departure_prefillsValueFromDraftDepartureDate() {
        let draft = CatchRecordDraft()
        draft.departureDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 3, day: 31))!

        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: draft
        )

        XCTAssertEqual(sut.value, DateEntryValue(day: "31", month: "3", year: "2026"))
    }

    func test_init_return_prefillsValueFromDraftReturnDate() {
        let draft = CatchRecordDraft()
        draft.returnDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 4, day: 2))!

        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: CatchRecordRouter(),
            draft: draft
        )

        XCTAssertEqual(sut.value, DateEntryValue(day: "2", month: "4", year: "2026"))
    }

    func test_init_withNoDraftDate_leavesValueBlank() {
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter(),
            draft: CatchRecordDraft()
        )

        XCTAssertEqual(sut.value, DateEntryValue())
    }
}
