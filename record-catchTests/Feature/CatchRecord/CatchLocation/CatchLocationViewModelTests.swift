import XCTest
@testable import record_catch

@MainActor
final class CatchLocationViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(router: CatchRecordRouter) -> CatchLocationViewModel {
        CatchLocationViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router
        )
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = makeSUT(router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.catchLocation.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withEmptySelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        sut.selectedArea = ""

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.catchLocation.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withSelection_routesToSpeciesSubJourney() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        sut.selectedArea = "38E96"

        // Await the sub-journey directly (rather than the fire-and-forget `Task` in `submit()`)
        // so the assertion is deterministic. With no favourite species, entry goes to Add-species.
        await sut.enterSpeciesSubJourney()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.addSpecies(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .recordWeights)]
        )
    }

    // MARK: - Draft capture

    func test_submit_withSelection_writesStatisticalAreaIntoDraft() {
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: .seineNets)]
        let sut = CatchLocationViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: draft
        )
        sut.selectedArea = "38E96"

        sut.submit()

        XCTAssertEqual(draft.gearCatches.first?.statisticalArea, "38E96")
    }

    func test_submit_withMultipleGears_writesAreaOnlyIntoMatchingGear() {
        let draft = CatchRecordDraft()
        let otherGear = GearOption(name: "Trawl nets")
        draft.gearCatches = [GearCatch(gear: .seineNets), GearCatch(gear: otherGear)]
        let sut = CatchLocationViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            draft: draft
        )
        sut.selectedArea = "38E96"

        sut.submit()

        XCTAssertEqual(draft.gearCatches[0].statisticalArea, "38E96")
        XCTAssertNil(draft.gearCatches[1].statisticalArea)
    }

    // MARK: - Manual entry ("Other" button)

    func test_enterManualEntry_pushesManualEntryRoute() {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)

        sut.enterManualEntry()

        XCTAssertEqual(
            router.path,
            [.catchLocationManualEntry(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber)]
        )
    }
}
