import XCTest
@testable import record_catch

/// Favourites provider whose `addFavourite` always throws, for exercising the save-failure path.
private struct FailingFavouritePortsProvider: FavouritePortsProviding {
    struct Failure: Error {}
    func favouritePorts() async throws -> [PortOption] { [] }
    func addFavourite(_ port: PortOption) async throws { throw Failure() }
}

@MainActor
final class AddPortViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        returnPhase: SelectPortPhase?,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider()
    ) -> AddPortViewModel {
        AddPortViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            returnPhase: returnPhase,
            router: router,
            portSearch: BundledPortSearchProvider(names: ["Aberdeen", "Hastings"]),
            favouritePorts: favouritePorts
        )
    }

    // MARK: - Loading

    func test_loadPorts_populatesPortNames() async {
        let sut = makeSUT(returnPhase: nil, router: CatchRecordRouter())

        await sut.loadPorts()

        XCTAssertFalse(sut.portNames.isEmpty)
        XCTAssertTrue(sut.portNames.contains("Aberdeen"))
    }

    // MARK: - Validation

    func test_submit_withNoSelection_setsError_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(returnPhase: nil, router: router)

        await sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.addPort.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = makeSUT(returnPhase: nil, router: CatchRecordRouter())
        sut.selectedName = nil
        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Completion routing

    func test_completionRoute_firstEntry_noSelection_returnsSelectPortDeparture() {
        let sut = makeSUT(returnPhase: nil, router: CatchRecordRouter())
        XCTAssertEqual(
            sut.completionRoute,
            .selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)
        )
    }

    func test_completionRoute_firstEntry_withSelection_returnsConfirmSamePort() {
        let sut = makeSUT(returnPhase: nil, router: CatchRecordRouter())
        sut.selectedName = "Hastings"
        XCTAssertEqual(
            sut.completionRoute,
            .confirmSamePort(vessel: vessel, referenceNumber: referenceNumber, port: PortOption(name: "Hastings"))
        )
    }

    func test_completionRoute_fromDeparture_returnsDeparture() {
        let sut = makeSUT(returnPhase: .departure, router: CatchRecordRouter())
        XCTAssertEqual(
            sut.completionRoute,
            .selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)
        )
    }

    func test_completionRoute_fromReturn_returnsReturn() {
        let sut = makeSUT(returnPhase: .return, router: CatchRecordRouter())
        XCTAssertEqual(
            sut.completionRoute,
            .selectPort(phase: .return, vessel: vessel, referenceNumber: referenceNumber)
        )
    }

    // MARK: - Submit success (adds favourite + routes)

    func test_submit_withSelection_addsFavourite_andRoutesToCompletion() async {
        let router = CatchRecordRouter()
        let favourites = StubFavouritePortsProvider()
        let sut = makeSUT(returnPhase: .return, router: router, favouritePorts: favourites)
        sut.selectedName = "Hastings"

        await sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertFalse(sut.saveFailed)
        let saved = try? await favourites.favouritePorts()
        XCTAssertEqual(saved?.map(\.name), ["Hastings"])
        XCTAssertEqual(
            router.path,
            [.selectPort(phase: .return, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_firstEntry_withSelection_routesToConfirmSamePort() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(returnPhase: nil, router: router)
        sut.selectedName = "Hastings"

        await sut.submit()

        XCTAssertEqual(
            router.path,
            [.confirmSamePort(vessel: vessel, referenceNumber: referenceNumber, port: PortOption(name: "Hastings"))]
        )
    }

    // MARK: - Submit failure (100% error path)

    func test_submit_whenSaveFails_setsSaveFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(returnPhase: nil, router: router, favouritePorts: FailingFavouritePortsProvider())
        sut.selectedName = "Hastings"

        await sut.submit()

        XCTAssertTrue(sut.saveFailed)
        XCTAssertTrue(router.path.isEmpty)
    }
}
