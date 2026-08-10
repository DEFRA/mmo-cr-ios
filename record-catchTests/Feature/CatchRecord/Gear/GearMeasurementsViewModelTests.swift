import XCTest
@testable import record_catch

/// Favourite-gear provider whose `addFavourite` always throws, for the save-failure path.
private struct FailingFavouriteGearProvider: FavouriteGearProviding {
    struct Failure: Error {}
    func favouriteGears() async throws -> [GearOption] { [] }
    func addFavourite(_ gear: GearOption) async throws { throw Failure() }
}

@MainActor
final class GearMeasurementsViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        router: CatchRecordRouter,
        favourites: FavouriteGearProviding = StubFavouriteGearProvider()
    ) -> GearMeasurementsViewModel {
        GearMeasurementsViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: favourites
        )
    }

    func test_entries_seededForEachMeasurement() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertEqual(sut.entries["meshSize"], "")
    }

    func test_submit_withInvalidValue_setsError_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        sut.entries["meshSize"] = "abc"

        await sut.submit()

        XCTAssertEqual(sut.errorKey(for: .init(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize")),
                       "catchRecord.gear.measurement.validation.wholeNumber")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_completionRoute_returnsSelectGear() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertEqual(
            sut.completionRoute,
            .selectGear(vessel: vessel, referenceNumber: referenceNumber)
        )
    }

    func test_submit_withValidValue_savesFavourite_andRoutesBack() async {
        let router = CatchRecordRouter()
        let favourites = StubFavouriteGearProvider()
        let sut = makeSUT(router: router, favourites: favourites)
        sut.entries["meshSize"] = "100"

        await sut.submit()

        XCTAssertFalse(sut.saveFailed)
        let saved = try? await favourites.favouriteGears()
        XCTAssertEqual(saved?.first?.measurements.first?.value, 100)
        XCTAssertEqual(
            router.path,
            [.selectGear(vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_whenSaveFails_setsSaveFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router, favourites: FailingFavouriteGearProvider())
        sut.entries["meshSize"] = "100"

        await sut.submit()

        XCTAssertTrue(sut.saveFailed)
        XCTAssertTrue(router.path.isEmpty)
    }
}
