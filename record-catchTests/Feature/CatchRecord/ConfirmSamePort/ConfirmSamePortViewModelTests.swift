import XCTest
@testable import record_catch

@MainActor
final class ConfirmSamePortViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"
    private let port = PortOption(name: "Hastings")

    private func makeSUT(
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) -> ConfirmSamePortViewModel {
        ConfirmSamePortViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            port: port,
            router: router,
            favouriteGears: favouriteGears,
            draft: draft
        )
    }

    func test_initialState_hasNoSelectionAndNoError_exposesPortAndReferenceNumber() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertNil(sut.selection)
        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(sut.port, port)
        XCTAssertEqual(sut.referenceNumber, referenceNumber)
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = makeSUT(router: CatchRecordRouter())
        sut.selection = nil
        XCTAssertNil(sut.errorKey)
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.confirmSamePort.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    // MARK: - "No" — continues into the departure select screen unchanged

    func test_submit_withNoSelected_pushesSelectPortDeparture_andDoesNotTouchDraft() {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        let sut = makeSUT(router: router, draft: draft)
        sut.selection = .no

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(router.path, [.selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)])
        XCTAssertNil(draft.departurePort)
        XCTAssertNil(draft.returnPort)
    }

    // MARK: - "Yes" — bypasses both select-port screens

    func test_submit_withYesSelected_setsBothDraftPorts_andEntersGearSubJourney_noFavourites() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        let sut = makeSUT(router: router, favouriteGears: StubFavouriteGearProvider(), draft: draft)
        sut.selection = .yes

        sut.submit()
        // `submit()` kicks off the async gear-entry lookup in a detached `Task`; await it directly
        // via the exposed method so the assertion isn't racing that task.
        await sut.enterGearSubJourney()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(draft.departurePort, port)
        XCTAssertEqual(draft.returnPort, port)
        XCTAssertEqual(router.path.last, .addGear(vessel: vessel, referenceNumber: referenceNumber))
    }

    func test_enterGearSubJourney_withFavourites_pushesSelectGear() async {
        let router = CatchRecordRouter()
        let favourites = StubFavouriteGearProvider(initialFavourites: [GearOption.seineNets])
        let sut = makeSUT(router: router, favouriteGears: favourites)

        await sut.enterGearSubJourney()

        XCTAssertEqual(router.path, [.selectGear(vessel: vessel, referenceNumber: referenceNumber)])
    }

    // MARK: - Add another port

    func test_addAnotherPort_pushesAddPort_withNilReturnPhase() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)

        sut.addAnotherPort()

        XCTAssertEqual(router.path, [.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: nil)])
    }
}
