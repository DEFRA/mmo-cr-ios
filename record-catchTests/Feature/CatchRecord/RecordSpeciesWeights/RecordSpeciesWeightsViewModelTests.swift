import XCTest
@testable import record_catch

@MainActor
final class RecordSpeciesWeightsViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        favourites: [SpeciesOption],
        router: CatchRecordRouter,
        draft: CatchRecordDraft
    ) -> RecordSpeciesWeightsViewModel {
        RecordSpeciesWeightsViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: favourites),
            draft: draft
        )
    }

    // MARK: - Routing

    func test_completionRoute_isLandingStorage() {
        let sut = makeSUT(favourites: [], router: CatchRecordRouter(), draft: CatchRecordDraft())

        XCTAssertEqual(sut.completionRoute, .landingStorage(referenceNumber: referenceNumber))
    }

    func test_submit_pushesLandingStorage() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(favourites: [], router: router, draft: CatchRecordDraft())

        await sut.submit()

        XCTAssertEqual(router.path, [.landingStorage(referenceNumber: referenceNumber)])
    }

    func test_addSpecies_pushesAddSpecies_carryingRecordWeightsReturnPhase() {
        let router = CatchRecordRouter()
        let sut = makeSUT(favourites: [], router: router, draft: CatchRecordDraft())

        sut.addSpecies()

        XCTAssertEqual(
            router.path,
            [.addSpecies(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .recordWeights)]
        )
    }

    // MARK: - Draft capture

    func test_submit_writesTickedSpeciesWithWeightsIntoDraft() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let draft = CatchRecordDraft()
        let sut = makeSUT(favourites: [cod], router: CatchRecordRouter(), draft: draft)
        await sut.loadFavourites()
        sut.selection = [cod.id]
        sut.aboveEntries[cod.id] = "250"

        await sut.submit()

        XCTAssertEqual(draft.speciesCaught.map(\.id), [cod.id])
        XCTAssertEqual(draft.speciesCaught.first?.weightAboveMinimumKg, "250")
    }

    func test_submit_excludesUntickedSpeciesFromDraft() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let bass = SpeciesOption(name: "Seabass (BSS)")
        let draft = CatchRecordDraft()
        let sut = makeSUT(favourites: [cod, bass], router: CatchRecordRouter(), draft: draft)
        await sut.loadFavourites()
        sut.selection = [cod.id]

        await sut.submit()

        XCTAssertEqual(draft.speciesCaught.map(\.id), [cod.id])
    }
}
