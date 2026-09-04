import XCTest
@testable import record_catch

@MainActor
final class SelectGearViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        router: CatchRecordRouter,
        favourites: [GearOption] = [.seineNets],
        draft: CatchRecordDraft = CatchRecordDraft()
    ) -> SelectGearViewModel {
        SelectGearViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouriteGears: StubFavouriteGearProvider(initialFavourites: favourites),
            draft: draft
        )
    }

    /// Seine nets with a captured required mesh size and its per-trip variable measurement, mirroring
    /// a real favourite loaded on this screen.
    private var seineNetsFavourite: GearOption {
        GearOption.seineNets.withRequiredMeasurements([
            GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 100)
        ])
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

    func test_variableErrorKey_beforeSubmit_isNil() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertNil(sut.variableErrorKey(gearID: GearOption.seineNets.id, measurementID: "timesShot"))
    }

    func test_submit_withSelection_butMissingVariableMeasurement_setsFieldError_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router, favourites: [seineNetsFavourite])
        await sut.loadFavourites()
        sut.selection = [GearOption.seineNets.id]

        sut.submit()

        XCTAssertNil(sut.errorKey) // a gear is selected, so no group-level error
        XCTAssertEqual(
            sut.variableErrorKey(gearID: GearOption.seineNets.id, measurementID: "timesShot"),
            "catchRecord.gear.measurement.validation.wholeNumber"
        )
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_variableErrorKey_forUnselectedGear_isNil_evenAfterSubmit() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router, favourites: [seineNetsFavourite])
        await sut.loadFavourites()

        sut.submit() // no selection

        XCTAssertNil(sut.variableErrorKey(gearID: GearOption.seineNets.id, measurementID: "timesShot"))
    }

    func test_submit_withValidVariableMeasurement_capturesValue_writesDraft_andRoutes() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        let sut = makeSUT(router: router, favourites: [seineNetsFavourite], draft: draft)
        await sut.loadFavourites()
        sut.selection = [GearOption.seineNets.id]
        sut.variableEntries["\(GearOption.seineNets.id).timesShot"] = "5"

        sut.submit()

        let expectedGear = seineNetsFavourite.withVariableMeasurements([
            GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot", value: 5)
        ])
        XCTAssertNil(sut.errorKey)
        XCTAssertNil(sut.variableErrorKey(gearID: GearOption.seineNets.id, measurementID: "timesShot"))
        XCTAssertEqual(draft.gearCatches.map(\.gear), [expectedGear])
        XCTAssertEqual(draft.gearCatches.first?.gear.variableMeasurements.first?.value, 5)
        XCTAssertEqual(
            router.path,
            [.catchLocation(gear: expectedGear, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    func test_submit_withMultipleTickedGears_capturesAllIntoDraft_inFavouritesOrder_andRoutesToFirst() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        let trawl = GearOption(name: "Trawl nets")
        let sut = makeSUT(router: router, favourites: [seineNetsFavourite, trawl], draft: draft)
        await sut.loadFavourites()
        sut.selection = [seineNetsFavourite.id, trawl.id]
        sut.variableEntries["\(GearOption.seineNets.id).timesShot"] = "5"

        sut.submit()

        XCTAssertEqual(draft.gearCatches.map(\.gear.name), ["Seine nets (not specified)", "Trawl nets"])
        XCTAssertTrue(draft.gearCatches.allSatisfy { $0.statisticalArea == nil && $0.speciesCaught.isEmpty })
        XCTAssertEqual(
            router.path,
            [.catchLocation(gear: draft.gearCatches[0].gear, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }

    // MARK: - Pre-population from an existing draft (see ADR-0013)

    /// Regression test: reaching this screen with gears already confirmed for the trip (e.g. via
    /// "Change" on a gear's variable measurements from Check your answers) must show every one of
    /// them ticked with its previously-entered variable-measurement value, not blank.
    func test_loadFavourites_withGearsAlreadyInDraft_preSelectsThem_andPrefillsVariableMeasurements() async {
        let trawl = GearOption(name: "Trawl nets", variableMeasurements: [.timesShot])
        let draft = CatchRecordDraft()
        draft.gearCatches = [
            GearCatch(gear: seineNetsFavourite.withVariableMeasurements([
                GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot", value: 5)
            ])),
            GearCatch(gear: trawl.withVariableMeasurements([
                GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot", value: 3)
            ]))
        ]
        let sut = makeSUT(router: CatchRecordRouter(), favourites: [seineNetsFavourite, trawl], draft: draft)

        await sut.loadFavourites()

        XCTAssertTrue(sut.selection.contains(GearOption.seineNets.id))
        XCTAssertTrue(sut.selection.contains(trawl.id))
        XCTAssertEqual(sut.variableEntries["\(GearOption.seineNets.id).timesShot"], "5")
        XCTAssertEqual(sut.variableEntries["\(trawl.id).timesShot"], "3")
    }

    func test_addAnotherGear_pushesAddGear() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)

        sut.addAnotherGear()

        XCTAssertEqual(router.path, [.addGear(vessel: vessel, referenceNumber: referenceNumber)])
    }

    // MARK: - Preserving already-captured progress (see ADR-0013)

    func test_submit_withGearAlreadyInDraft_preservesItsStatisticalAreaAndSpeciesCaught() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.gearCatches = [
            GearCatch(
                gear: seineNetsFavourite,
                statisticalArea: "27.7.e",
                speciesCaught: [SpeciesOption(name: "Atlantic cod (COD)").withWeights(above: "250", below: nil, discarded: nil)]
            )
        ]
        let sut = makeSUT(router: router, favourites: [seineNetsFavourite], draft: draft)
        await sut.loadFavourites()
        sut.selection = [GearOption.seineNets.id]
        sut.variableEntries["\(GearOption.seineNets.id).timesShot"] = "9"

        sut.submit()

        XCTAssertEqual(draft.gearCatches.first?.statisticalArea, "27.7.e")
        XCTAssertEqual(draft.gearCatches.first?.speciesCaught.first?.name, "Atlantic cod (COD)")
        XCTAssertEqual(draft.gearCatches.first?.gear.variableMeasurements.first?.value, 9)
    }

    // MARK: - Resume at Check your answers

    func test_submit_whenResumingAtCheckYourAnswers_pushesCheckYourAnswers_insteadOfCatchLocation() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        draft.returnToCheckYourAnswers = true
        let sut = makeSUT(router: router, favourites: [seineNetsFavourite], draft: draft)
        await sut.loadFavourites()
        sut.selection = [GearOption.seineNets.id]
        sut.variableEntries["\(GearOption.seineNets.id).timesShot"] = "5"

        sut.submit()

        XCTAssertEqual(router.path, [.checkYourAnswers(referenceNumber: referenceNumber)])
        XCTAssertFalse(draft.returnToCheckYourAnswers)
    }
}
