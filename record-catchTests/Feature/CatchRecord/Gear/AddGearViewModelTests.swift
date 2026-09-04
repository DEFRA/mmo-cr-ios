import XCTest
@testable import record_catch

/// Favourite-gear provider whose `addFavourite` always throws, for the save-failure path when a
/// zero-measurement gear is saved straight to favourites.
private struct FailingFavouriteGearProvider: FavouriteGearProviding {
    struct Failure: Error {}
    func favouriteGears() async throws -> [GearOption] { [] }
    func addFavourite(_ gear: GearOption) async throws { throw Failure() }
}

@MainActor
final class AddGearViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    /// A gear with no required measurements at all (mirrors `HMD`/`MIS` in the catalogue — see
    /// ADR-0012), used to exercise the skip-straight-to-favourites path.
    private let noMeasurementGear = GearOption(id: "MIS", name: "Miscellaneous gear (diving)")

    private func makeSUT(
        router: CatchRecordRouter,
        gearSearch: GearSearchProviding = StubGearSearchProvider(gears: [.seineNets]),
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider()
    ) -> AddGearViewModel {
        AddGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            gearSearch: gearSearch,
            favouriteGears: favouriteGears
        )
    }

    func test_loadGears_populatesGearNames() async {
        let sut = makeSUT(router: CatchRecordRouter())
        await sut.loadGears()
        XCTAssertEqual(sut.gearNames, ["Seine nets (not specified)"])
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        await sut.loadGears()

        await sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.addGear.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }

    func test_submit_withSelection_havingRequiredMeasurements_routesToMeasurements() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        await sut.loadGears()
        sut.selectedName = "Seine nets (not specified)"

        await sut.submit()

        XCTAssertEqual(
            router.path,
            [.gearMeasurements(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_withSelection_havingNoRequiredMeasurements_savesFavourite_andRoutesToSelectGear() async {
        let router = CatchRecordRouter()
        let favourites = StubFavouriteGearProvider()
        let sut = makeSUT(
            router: router,
            gearSearch: StubGearSearchProvider(gears: [noMeasurementGear]),
            favouriteGears: favourites
        )
        await sut.loadGears()
        sut.selectedName = noMeasurementGear.name

        await sut.submit()

        XCTAssertFalse(sut.saveFailed)
        let saved = try? await favourites.favouriteGears()
        XCTAssertEqual(saved?.map(\.id), [noMeasurementGear.id])
        XCTAssertEqual(
            router.path,
            [.selectGear(vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_withNoRequiredMeasurements_whenSaveFails_setsSaveFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(
            router: router,
            gearSearch: StubGearSearchProvider(gears: [noMeasurementGear]),
            favouriteGears: FailingFavouriteGearProvider()
        )
        await sut.loadGears()
        sut.selectedName = noMeasurementGear.name

        await sut.submit()

        XCTAssertTrue(sut.saveFailed)
        XCTAssertTrue(router.path.isEmpty)
    }
}
