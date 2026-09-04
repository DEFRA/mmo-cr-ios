import XCTest
@testable import record_catch

@MainActor
final class SelectPortViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        phase: SelectPortPhase,
        router: CatchRecordRouter,
        favourites: [PortOption] = [PortOption(name: "Hastings")],
        favouriteGears: [GearOption] = []
    ) -> SelectPortViewModel {
        SelectPortViewModel(
            phase: phase,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: StubFavouritePortsProvider(initialFavourites: favourites),
            favouriteGears: StubFavouriteGearProvider(initialFavourites: favouriteGears)
        )
    }

    func test_loadFavourites_populatesFavourites() async {
        let sut = makeSUT(phase: .departure, router: CatchRecordRouter(), favourites: [PortOption(name: "Hastings"), PortOption(name: "Newlyn")])

        await sut.loadFavourites()

        XCTAssertEqual(sut.favourites.map(\.name), ["Hastings", "Newlyn"])
    }

    func test_submit_withNoSelection_setsPhaseError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = makeSUT(phase: .departure, router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.selectPort.departure.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_departure_withSelection_pushesReturn() {
        let router = CatchRecordRouter()
        let sut = makeSUT(phase: .departure, router: router)
        sut.selection = "Hastings"

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.selectPort(phase: .return, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_return_withSelection_entersGearSubJourney_noGearFavourites_pushesAddGear() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(phase: .return, router: router, favouriteGears: [])
        sut.selection = "Hastings"

        await sut.enterGearSubJourney()

        XCTAssertEqual(router.path, [.addGear(vessel: vessel, referenceNumber: referenceNumber)])
    }

    func test_submit_return_withSelection_entersGearSubJourney_withGearFavourites_pushesSelectGear() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(phase: .return, router: router, favouriteGears: [.seineNets])
        sut.selection = "Hastings"

        await sut.enterGearSubJourney()

        XCTAssertEqual(router.path, [.selectGear(vessel: vessel, referenceNumber: referenceNumber)])
    }

    func test_addAnotherPort_fromDeparture_pushesAddPortCarryingDeparturePhase() {
        let router = CatchRecordRouter()
        let sut = makeSUT(phase: .departure, router: router)

        sut.addAnotherPort()

        XCTAssertEqual(
            router.path,
            [.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: .departure)]
        )
    }

    func test_addAnotherPort_fromReturn_pushesAddPortCarryingReturnPhase() {
        let router = CatchRecordRouter()
        let sut = makeSUT(phase: .return, router: router)

        sut.addAnotherPort()

        XCTAssertEqual(
            router.path,
            [.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: .return)]
        )
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = makeSUT(phase: .departure, router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Draft capture

    func test_submit_departure_withSelection_writesDeparturePortIntoDraft() async {
        let draft = CatchRecordDraft()
        let sut = SelectPortViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")]),
            draft: draft
        )
        await sut.loadFavourites()
        sut.selection = "Hastings"

        sut.submit()

        XCTAssertEqual(draft.departurePort, PortOption(name: "Hastings"))
        XCTAssertNil(draft.returnPort)
    }

    func test_submit_return_withSelection_writesReturnPortIntoDraft() async {
        let draft = CatchRecordDraft()
        let sut = SelectPortViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")]),
            draft: draft
        )
        await sut.loadFavourites()
        sut.selection = "Hastings"

        sut.submit()

        XCTAssertEqual(draft.returnPort, PortOption(name: "Hastings"))
    }

    // MARK: - Resume at Check your answers (see ADR-0013)

    func test_submit_departure_whenResumingAtCheckYourAnswers_pushesCheckYourAnswers_insteadOfReturnPhase() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.returnToCheckYourAnswers = true
        let sut = SelectPortViewModel(
            phase: .departure,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")]),
            draft: draft
        )
        await sut.loadFavourites()
        sut.selection = "Hastings"

        sut.submit()

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswers)
    }

    func test_submit_return_whenResumingAtCheckYourAnswers_pushesCheckYourAnswers_insteadOfGearSubJourney() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.returnToCheckYourAnswers = true
        let sut = SelectPortViewModel(
            phase: .return,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")]),
            draft: draft
        )
        await sut.loadFavourites()
        sut.selection = "Hastings"

        sut.submit()

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswers)
    }
}
