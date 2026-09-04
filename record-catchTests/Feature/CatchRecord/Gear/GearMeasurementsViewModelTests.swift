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
        favourites: FavouriteGearProviding = StubFavouriteGearProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) -> GearMeasurementsViewModel {
        GearMeasurementsViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: favourites,
            draft: draft
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
        XCTAssertEqual(saved?.first?.requiredMeasurements.first?.value, 100)
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

    // MARK: - Draft sync (see ADR-0013)

    func test_submit_withValidValue_whenGearIsAlreadyInDraft_updatesItInPlace_preservingLocationAndSpecies() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.gearCatches = [
            GearCatch(
                gear: .seineNets,
                statisticalArea: "27.7.e",
                speciesCaught: [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)]
            )
        ]
        let sut = makeSUT(router: router, draft: draft)
        sut.entries["meshSize"] = "100"

        await sut.submit()

        XCTAssertEqual(draft.gearCatches.first?.gear.requiredMeasurements.first?.value, 100)
        XCTAssertEqual(draft.gearCatches.first?.statisticalArea, "27.7.e")
        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.first?.name, "Atlantic cod (COD)")
    }

    // MARK: - Resume at Check your answers

    func test_submit_whenResumingAtCheckYourAnswers_pushesCheckYourAnswers_insteadOfSelectGear() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.returnToCheckYourAnswers = true
        let sut = makeSUT(router: router, draft: draft)
        sut.entries["meshSize"] = "100"

        await sut.submit()

        XCTAssertFalse(sut.saveFailed)
        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswers)
    }
}
