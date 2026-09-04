import XCTest
@testable import record_catch

@MainActor
final class CatchLocationManualEntryViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"

    private func makeSUT(
        router: CatchRecordRouter,
        subrectangleSearch: SubrectangleSearchProviding = BundledSubrectangleSearchProvider(codes: ["38E84", "38E95", "38E96"]),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) -> CatchLocationManualEntryViewModel {
        CatchLocationManualEntryViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            subrectangleSearch: subrectangleSearch,
            draft: draft
        )
    }

    // MARK: - Loading

    func test_loadCodes_populatesCodes() async {
        let sut = makeSUT(router: CatchRecordRouter())

        await sut.loadCodes()

        XCTAssertEqual(sut.codes, ["38E84", "38E95", "38E96"])
    }

    // MARK: - Validation

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

    // MARK: - Submit success

    func test_submit_withSelection_writesStatisticalAreaIntoDraft() {
        let draft = CatchRecordDraft()
        draft.gearCatches = [GearCatch(gear: .seineNets)]
        let sut = makeSUT(router: CatchRecordRouter(), draft: draft)
        sut.selectedCode = "38E95"

        sut.submit()

        XCTAssertEqual(draft.gearCatches.first?.statisticalArea, "38E95")
    }

    func test_submit_withSelection_routesToSpeciesSubJourney() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        sut.selectedCode = "38E95"

        // Await the sub-journey directly (rather than the fire-and-forget `Task` in `submit()`)
        // so the assertion is deterministic. With no favourite species, entry goes to Add-species.
        await sut.enterSpeciesSubJourney()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.addSpecies(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber, returnPhase: .recordWeights)]
        )
    }
}
