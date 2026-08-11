import XCTest
@testable import record_catch

@MainActor
final class TripDateViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeValidDate() -> DateEntryValue {
        DateEntryValue(day: "31", month: "03", year: "2020")
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
        XCTAssertNil(sut.errorKey)
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

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.tripDate.validation.none")
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

        sut.submit()

        XCTAssertNil(sut.errorKey)
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

    func test_errorKey_beforeSubmit_isNil() {
        let sut = TripDateViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: nil,
            router: CatchRecordRouter()
        )
        sut.value = DateEntryValue()
        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Submit: return date late-submission nudge

    func test_submit_return_whenTripEndedMoreThan24HoursAgo_pushesSubmissionNudge() {
        let router = CatchRecordRouter()
        // Return date 31/03/2020; "now" is many days later, so the nudge is required.
        let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2020, month: 4, day: 3, hour: 12))!
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: router,
            now: { now }
        )
        sut.value = makeValidDate()

        sut.submit()

        XCTAssertNil(sut.errorKey)
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
            departureDate: Date(),
            router: router,
            favouritePorts: StubFavouritePortsProvider(),
            now: { end.addingTimeInterval(60 * 60) }
        )
        sut.value = makeValidDate()

        sut.submit()

        XCTAssertNil(sut.errorKey)
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

        sut.submit()

        XCTAssertEqual(draft.departureDate, DateEntryField.parsedDate(from: makeValidDate()))
        XCTAssertNil(draft.returnDate)
    }

    func test_submit_return_withValidDate_writesReturnDateIntoDraft() {
        let draft = CatchRecordDraft()
        let sut = TripDateViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: Date(),
            router: CatchRecordRouter(),
            draft: draft,
            now: { DateEntryField.parsedDate(from: self.makeValidDate())!.addingTimeInterval(60 * 60) }
        )
        sut.value = makeValidDate()

        sut.submit()

        XCTAssertEqual(draft.returnDate, DateEntryField.parsedDate(from: makeValidDate()))
    }
}
