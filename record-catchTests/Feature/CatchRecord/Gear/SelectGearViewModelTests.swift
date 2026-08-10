import XCTest
@testable import record_catch

@MainActor
final class SelectGearViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        router: CatchRecordRouter,
        favourites: [GearOption] = [.seineNets]
    ) -> SelectGearViewModel {
        SelectGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: StubFavouriteGearProvider(initialFavourites: favourites)
        )
    }

    func test_loadFavourites_populatesFavourites() async {
        let sut = makeSUT(router: CatchRecordRouter())
        await sut.loadFavourites()
        XCTAssertEqual(sut.favourites.map(\.name), ["Seine nets (not specified)"])
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.selectGear.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }

    func test_submit_withSelection_routesToCatchLocationForSelectedGear() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        await sut.loadFavourites()
        sut.selection = ["Seine nets (not specified)"]

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.catchLocation(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_addAnotherGear_pushesAddGear() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)

        sut.addAnotherGear()

        XCTAssertEqual(router.path, [.addGear(vessel: vessel, referenceNumber: referenceNumber)])
    }
}
