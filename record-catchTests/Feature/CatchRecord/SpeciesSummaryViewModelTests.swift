import XCTest
@testable import record_catch

@MainActor
final class SpeciesSummaryViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    func test_loadSpecies_populatesSpeciesFromFavourites() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "12", below: nil, discarded: nil)
        let provider = StubFavouriteSpeciesProvider(initialFavourites: [cod])
        let sut = SpeciesSummaryViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            favouriteSpecies: provider
        )

        await sut.loadSpecies()

        XCTAssertEqual(sut.species, [cod])
    }

    func test_addAnother_pushesAddSpecies_carryingSummaryReturnPhase() {
        let router = CatchRecordRouter()
        let sut = SpeciesSummaryViewModel(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber, router: router)

        sut.addAnother()

        XCTAssertEqual(
            router.path,
            [.addSpecies(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .summary)]
        )
    }

    func test_submit_pushesLandingStorage() {
        let router = CatchRecordRouter()
        let sut = SpeciesSummaryViewModel(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber, router: router)

        sut.submit()

        XCTAssertEqual(router.path, [.landingStorage(referenceNumber: referenceNumber)])
    }

    // MARK: - Draft capture

    func test_submit_writesLoadedSpeciesIntoDraftAsSpeciesCaught() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)
        let provider = StubFavouriteSpeciesProvider(initialFavourites: [cod])
        let draft = CatchRecordDraft()
        let sut = SpeciesSummaryViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            favouriteSpecies: provider,
            draft: draft
        )
        await sut.loadSpecies()

        sut.submit()

        XCTAssertEqual(draft.speciesCaught, [cod])
    }
}
