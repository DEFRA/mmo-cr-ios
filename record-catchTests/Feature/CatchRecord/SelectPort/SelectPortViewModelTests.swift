import XCTest
@testable import record_catch

@MainActor
final class SelectPortViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        phase: SelectPortPhase,
        router: CatchRecordRouter,
        favourites: [PortOption] = [PortOption(name: "Hastings")]
    ) -> SelectPortViewModel {
        SelectPortViewModel(
            phase: phase,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: StubFavouritePortsProvider(initialFavourites: favourites)
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

    func test_submit_return_withSelection_pushesPlaceholderNextStep() {
        let router = CatchRecordRouter()
        let sut = makeSUT(phase: .return, router: router)
        sut.selection = "Hastings"

        sut.submit()

        XCTAssertEqual(router.path, [.placeholderNextStep])
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
}
