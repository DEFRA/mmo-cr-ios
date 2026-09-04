import XCTest
@testable import record_catch

@MainActor
final class SpeciesSubJourneyEntryTests: XCTestCase {

    private let gear = GearOption.seineNets
    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    func test_enter_withNoFavourites_routesToAddSpecies() async {
        let router = CatchRecordRouter()

        await SpeciesSubJourneyEntry.enter(
            router: router,
            favouriteSpecies: StubFavouriteSpeciesProvider(),
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber
        )

        XCTAssertEqual(
            router.path,
            [.addSpecies(gear: gear, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .recordWeights)]
        )
    }

    func test_enter_withFavourites_routesToRecordSpeciesWeights() async throws {
        let router = CatchRecordRouter()
        let favourites = StubFavouriteSpeciesProvider()
        try await favourites.addFavourite(SpeciesOption(name: "Cod"))

        await SpeciesSubJourneyEntry.enter(
            router: router,
            favouriteSpecies: favourites,
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber
        )

        XCTAssertEqual(
            router.path,
            [.recordSpeciesWeights(gear: gear, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }
}
