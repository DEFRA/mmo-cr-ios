import XCTest
@testable import record_catch

@MainActor
final class TripStartedTodayViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    func test_initialState_hasNoSelectionAndNoError_exposesReferenceNumber() {
        let sut = TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: CatchRecordRouter())
        XCTAssertNil(sut.selection)
        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
        XCTAssertEqual(sut.vessel, vessel)
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.tripToday.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_enterPortSubJourney_withNoFavourites_pushesAddPort() async {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: StubFavouritePortsProvider()
        )

        await sut.enterPortSubJourney()

        XCTAssertEqual(
            router.path,
            [.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: nil)]
        )
    }

    func test_enterPortSubJourney_withFavourites_pushesSelectDeparture() async {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
        )

        await sut.enterPortSubJourney()

        XCTAssertEqual(
            router.path,
            [.selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_withNoSelection_pushesTripDateDepartureWithNoDepartureDate() {
        let router = CatchRecordRouter()
        let sut = TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: router)
        sut.selection = .no

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.tripDate(phase: .departure, vessel: vessel, referenceNumber: referenceNumber, departureDate: nil)]
        )
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Checkpoint (see ADR-0014 decision #5, amended — resume at the last completed section)

    func test_submit_withYesSelected_advancesCheckpointToTripDates() {
        let draft = CatchRecordDraft()
        let sut = TripStartedTodayViewModel(
            vessel: vessel, referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft
        )
        sut.selection = .yes

        sut.submit()

        XCTAssertEqual(draft.checkpoint, .tripDates)
    }

    func test_submit_withNoSelected_doesNotAdvanceCheckpointYet() {
        let draft = CatchRecordDraft()
        let sut = TripStartedTodayViewModel(
            vessel: vessel, referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft
        )
        sut.selection = .no

        sut.submit()

        XCTAssertEqual(draft.checkpoint, .vessel)
    }

    // MARK: - Same-day trip dates (BUG: "Yes" previously left departureDate/returnDate nil, so
    // the date never appeared on Check your answers or the Home records list — see
    // `CheckYourAnswersViewModel.tripRows` and `RecordsRepository.row(for:)`, both of which are a
    // pure projection of `draft.departureDate`/`draft.returnDate`.)

    func test_submit_withYesSelected_setsDepartureAndReturnDateToStartOfToday() {
        let draft = CatchRecordDraft()
        let fixedNow = DateComponents(
            calendar: Calendar(identifier: .gregorian), year: 2026, month: 7, day: 27, hour: 15, minute: 8
        ).date!
        let sut = TripStartedTodayViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: draft,
            now: { fixedNow }
        )
        sut.selection = .yes

        sut.submit()

        let expectedStartOfDay = Calendar(identifier: .gregorian).startOfDay(for: fixedNow)
        XCTAssertEqual(draft.departureDate, expectedStartOfDay)
        XCTAssertEqual(draft.returnDate, expectedStartOfDay)
        XCTAssertEqual(draft.departureDate, draft.returnDate)
    }

    func test_submit_withNoSelected_leavesDepartureAndReturnDateNil() {
        let draft = CatchRecordDraft()
        let sut = TripStartedTodayViewModel(
            vessel: vessel, referenceNumber: referenceNumber, router: CatchRecordRouter(), draft: draft
        )
        sut.selection = .no

        sut.submit()

        XCTAssertNil(draft.departureDate)
        XCTAssertNil(draft.returnDate)
    }
}
