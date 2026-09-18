import XCTest
@testable import record_catch

/// Favourite-species provider whose `addFavourite` always throws, to exercise the save-failure path.
private struct FailingFavouriteSpeciesProvider: FavouriteSpeciesProviding {
    struct Failure: Error {}
    func favouriteSpecies() async throws -> [SpeciesOption] { [] }
    func addFavourite(_ species: SpeciesOption) async throws { throw Failure() }
    func removeFavourite(id: String) async throws {}
}

@MainActor
final class AddSpeciesViewModelTests: XCTestCase {

    private let gear = GearOption.seineNets
    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"
    private let cod = SpeciesOption(name: "Atlantic cod (COD)")

    private func makeSUT(
        context: AddSpeciesContext = .firstTime,
        router: CatchRecordRouter,
        speciesSearch: SpeciesSearchProviding = StubSpeciesSearchProvider(names: ["Atlantic cod (COD)"]),
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider()
    ) -> AddSpeciesViewModel {
        AddSpeciesViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            returnPhase: .recordWeights,
            context: context,
            router: router,
            speciesSearch: speciesSearch,
            favouriteSpecies: favouriteSpecies
        )
    }

    func test_loadSpecies_populatesSpeciesNames() async {
        let sut = makeSUT(router: CatchRecordRouter())
        await sut.loadSpecies()
        XCTAssertEqual(sut.speciesNames, ["Atlantic cod (COD)"])
    }

    // MARK: - Validation

    func test_submit_withEmptyQuery_firstTime_setsEnterMessage_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(context: .firstTime, router: router)

        await sut.submit()

        XCTAssertEqual(sut.validationMessage?.key, "catchRecord.species.add.validation.enter")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withTypedButUnselectedQuery_firstTime_setsSelectMessage() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(context: .firstTime, router: router)
        sut.query = "cod"

        await sut.submit()

        XCTAssertEqual(sut.validationMessage?.key, "catchRecord.species.add.validation.select")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withEmptyQuery_addAnother_setsEnterMessage() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(context: .addAnother, router: router)

        await sut.submit()

        XCTAssertEqual(sut.validationMessage?.key, "catchRecord.species.trip.validation.enter")
    }

    func test_submit_withTypedButUnselectedQuery_addAnother_setsSelectMessage() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(context: .addAnother, router: router)
        sut.query = "cod"

        await sut.submit()

        XCTAssertEqual(sut.validationMessage?.key, "catchRecord.species.trip.validation.select")
    }

    func test_validationMessage_beforeSubmit_isNil() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertNil(sut.validationMessage)
    }

    // MARK: - Success

    func test_submit_withValidSelection_savesFavourite_andRoutesToRecordWeights() async {
        let router = CatchRecordRouter()
        let favourites = StubFavouriteSpeciesProvider()
        let sut = makeSUT(router: router, favouriteSpecies: favourites)
        sut.query = cod.name
        sut.selectedName = cod.name

        await sut.submit()

        XCTAssertNil(sut.validationMessage)
        let saved = try? await favourites.favouriteSpecies()
        XCTAssertEqual(saved?.map(\.id), [cod.id])
        XCTAssertEqual(
            router.path,
            [.recordSpeciesWeights(gear: gear, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_whenSaveFails_setsSaveFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router, favouriteSpecies: FailingFavouriteSpeciesProvider())
        sut.query = cod.name
        sut.selectedName = cod.name

        await sut.submit()

        XCTAssertTrue(sut.saveFailed)
        XCTAssertTrue(router.path.isEmpty)
    }
}
