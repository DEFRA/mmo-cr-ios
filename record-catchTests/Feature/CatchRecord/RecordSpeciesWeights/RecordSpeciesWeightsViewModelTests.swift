import XCTest
@testable import record_catch

@MainActor
final class RecordSpeciesWeightsViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        gear: GearOption = .seineNets,
        favourites: [SpeciesOption],
        router: CatchRecordRouter,
        draft: CatchRecordDraft
    ) -> RecordSpeciesWeightsViewModel {
        RecordSpeciesWeightsViewModel(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteSpecies: StubFavouriteSpeciesProvider(initialFavourites: favourites),
            draft: draft
        )
    }

    /// A draft with a single selected gear (seine nets), matching most tests' single-gear journey.
    private func singleGearDraft() -> CatchRecordDraft {
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: .seineNets)]
        return draft
    }

    // MARK: - Routing (single gear)

    func test_completionRoute_forSingleGear_isLandingStorage() {
        let sut = makeSUT(favourites: [], router: CatchRecordRouter(), draft: singleGearDraft())

        XCTAssertEqual(sut.completionRoute, .landingStorage(referenceNumber: referenceNumber))
    }

    func test_submit_forSingleGear_pushesLandingStorage() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(favourites: [], router: router, draft: singleGearDraft())

        await sut.submit()

        XCTAssertEqual(router.path, [.landingStorage(referenceNumber: referenceNumber)])
    }

    func test_addSpecies_pushesAddSpecies_carryingRecordWeightsReturnPhase() {
        let router = CatchRecordRouter()
        let sut = makeSUT(favourites: [], router: router, draft: singleGearDraft())

        sut.addSpecies()

        XCTAssertEqual(
            router.path,
            [.addSpecies(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .recordWeights)]
        )
    }

    // MARK: - Routing (multi-gear loop — see ADR-0011)

    func test_completionRoute_whenMoreGearsRemain_loopsBackToCatchLocationForNextGear() {
        let trawl = GearOption(name: "Trawl nets")
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: .seineNets), GearCatch(gear: trawl)]
        let sut = makeSUT(gear: .seineNets, favourites: [], router: CatchRecordRouter(), draft: draft)

        XCTAssertEqual(
            sut.completionRoute,
            .catchLocation(gear: trawl, vessel: vessel, referenceNumber: referenceNumber)
        )
    }

    func test_completionRoute_forLastOfMultipleGears_isLandingStorage() {
        let trawl = GearOption(name: "Trawl nets")
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: .seineNets), GearCatch(gear: trawl)]
        let sut = makeSUT(gear: trawl, favourites: [], router: CatchRecordRouter(), draft: draft)

        XCTAssertEqual(sut.completionRoute, .landingStorage(referenceNumber: referenceNumber))
    }

    func test_submit_whenMoreGearsRemain_pushesCatchLocationForNextConfirmedGear() async {
        let trawl = GearOption(name: "Trawl nets").withVariableMeasurements([
            GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot", value: 3)
        ])
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: .seineNets), GearCatch(gear: trawl)]
        let sut = makeSUT(gear: .seineNets, favourites: [], router: router, draft: draft)

        await sut.submit()

        // The confirmed gear (with its captured measurements) is threaded onward, not a bare favourite.
        XCTAssertEqual(router.path, [.catchLocation(gear: trawl, vessel: vessel, referenceNumber: referenceNumber)])
    }

    // MARK: - Routing (resuming from Check your answers — see ADR-0011)

    func test_completionRoute_whenResumingAtCheckYourAnswers_returnsThereEvenWithMoreGearsRemaining() {
        let trawl = GearOption(name: "Trawl nets")
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: .seineNets), GearCatch(gear: trawl)]
        draft.returnToCheckYourAnswersAfterSpecies = true
        let sut = makeSUT(gear: .seineNets, favourites: [], router: CatchRecordRouter(), draft: draft)

        XCTAssertEqual(sut.completionRoute, .checkYourAnswers(referenceNumber: referenceNumber))
    }

    func test_submit_whenResumingAtCheckYourAnswers_pushesCheckYourAnswers_andClearsFlag() async {
        let router = CatchRecordRouter()
        let draft = singleGearDraft()
        draft.returnToCheckYourAnswersAfterSpecies = true
        let sut = makeSUT(favourites: [], router: router, draft: draft)

        await sut.submit()

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswersAfterSpecies)
    }

    // MARK: - Draft capture

    func test_submit_writesTickedSpeciesWithWeightsIntoDraft() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let draft = singleGearDraft()
        let sut = makeSUT(favourites: [cod], router: CatchRecordRouter(), draft: draft)
        await sut.loadFavourites()
        sut.selection = [cod.id]
        sut.aboveEntries[cod.id] = "250"

        await sut.submit()

        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.map(\.id), [cod.id])
        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.first?.weightAboveMinimumKg, "250")
    }

    func test_submit_excludesUntickedSpeciesFromDraft() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let bass = SpeciesOption(name: "Seabass (BSS)")
        let draft = singleGearDraft()
        let sut = makeSUT(favourites: [cod, bass], router: CatchRecordRouter(), draft: draft)
        await sut.loadFavourites()
        sut.selection = [cod.id]

        await sut.submit()

        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.map(\.id), [cod.id])
    }

    func test_submit_withMultipleGears_writesSpeciesOnlyIntoMatchingGear() async {
        let cod = SpeciesOption(name: "Atlantic cod (COD)")
        let trawl = GearOption(name: "Trawl nets")
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: .seineNets), GearCatch(gear: trawl)]
        let sut = makeSUT(gear: .seineNets, favourites: [cod], router: CatchRecordRouter(), draft: draft)
        await sut.loadFavourites()
        sut.selection = [cod.id]

        await sut.submit()

        XCTAssertEqual(draft.gearCatches[0].speciesCaught.map(\.id), [cod.id])
        XCTAssertTrue(draft.gearCatches[1].speciesCaught.isEmpty)
    }
}
