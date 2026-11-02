import XCTest
@testable import record_catch

@MainActor
final class CatchLocationNearestAreasViewModelTests: XCTestCase {

    private let vessel = "ACHILLES"
    private let referenceNumber = "A1234520260727150815"
    private let plymouth = PortCoordinate(latitude: 50.3660, longitude: -4.1427)

    /// Deterministic stand-in for `BundledNearestSubrectangleProvider`, so these tests never touch
    /// the real bundled map data (mirrors how `CatchLocationManualEntryViewModelTests` stubs
    /// `SubrectangleSearchProviding`).
    private struct StubNearestSubrectangleProvider: NearestSubrectangleProviding {
        let codes: [String]
        var error: Error?

        func nearestCodes(to coordinate: PortCoordinate, limit: Int) async throws -> [String] {
            if let error { throw error }
            return Array(codes.prefix(limit))
        }
    }

    private enum StubError: Error { case failed }

    private func makeSUT(
        router: CatchRecordRouter,
        nearestSubrectangleProvider: NearestSubrectangleProviding = StubNearestSubrectangleProvider(codes: ["38E84", "38E86", "38E85"]),
        draft: CatchRecordDraft? = nil
    ) -> CatchLocationNearestAreasViewModel {
        let resolvedDraft = draft ?? {
            let draft = CatchRecordDraft()
            draft.departurePort = PortOption(name: "Plymouth", coordinate: plymouth)
            return draft
        }()
        return CatchLocationNearestAreasViewModel(
            gear: .seineNets,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            nearestSubrectangleProvider: nearestSubrectangleProvider,
            draft: resolvedDraft
        )
    }

    // MARK: - Loading

    func test_loadAreas_withDeparturePort_populatesAreasInOrder() async {
        let sut = makeSUT(router: CatchRecordRouter())

        await sut.loadAreas()

        XCTAssertEqual(sut.areas, ["38E84", "38E86", "38E85"])
    }

    func test_loadAreas_requestsAreaLimit() async {
        var requestedLimit: Int?
        struct CapturingProvider: NearestSubrectangleProviding {
            let onRequest: (Int) -> Void
            func nearestCodes(to coordinate: PortCoordinate, limit: Int) async throws -> [String] {
                onRequest(limit)
                return []
            }
        }
        let sut = makeSUT(
            router: CatchRecordRouter(),
            nearestSubrectangleProvider: CapturingProvider { requestedLimit = $0 }
        )

        await sut.loadAreas()

        XCTAssertEqual(requestedLimit, CatchLocationNearestAreasViewModel.areaLimit)
    }

    func test_loadAreas_withNoDeparturePort_leavesAreasEmpty() async {
        let draft = CatchRecordDraft()
        let sut = makeSUT(router: CatchRecordRouter(), draft: draft)

        await sut.loadAreas()

        XCTAssertEqual(sut.areas, [])
    }

    func test_loadAreas_whenProviderThrows_leavesAreasEmpty() async {
        let sut = makeSUT(
            router: CatchRecordRouter(),
            nearestSubrectangleProvider: StubNearestSubrectangleProvider(codes: [], error: StubError.failed)
        )

        await sut.loadAreas()

        XCTAssertEqual(sut.areas, [])
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

        XCTAssertEqual(sut.errorKey, "catchRecord.nearestAreas.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    // MARK: - Selecting a listed area

    func test_submit_withAreaSelected_writesStatisticalAreaIntoDraft() {
        let draft = CatchRecordDraft()
        draft.departurePort = PortOption(name: "Plymouth", coordinate: plymouth)
        draft.gearCatches = [GearCatch(gear: .seineNets)]
        let sut = makeSUT(router: CatchRecordRouter(), draft: draft)
        sut.selection = "38E86"

        sut.submit()

        XCTAssertEqual(draft.gearCatches.first?.statisticalArea, "38E86")
    }

    func test_submit_withAreaSelected_routesToSpeciesSubJourney() async {
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router)
        sut.selection = "38E86"

        // Await the sub-journey directly (rather than the fire-and-forget `Task` in `submit()`)
        // so the assertion is deterministic. With no favourite species, entry goes to Add-species.
        await sut.enterSpeciesSubJourney()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [
                .addSpecies(
                    gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber,
                    returnPhase: .recordWeights, context: .firstTime
                )
            ]
        )
    }

    // MARK: - Selecting "Other"

    func test_submit_withOtherSelected_pushesManualEntryRoute_andDoesNotWriteDraft() {
        let draft = CatchRecordDraft()
        draft.departurePort = PortOption(name: "Plymouth", coordinate: plymouth)
        draft.gearCatches = [GearCatch(gear: .seineNets)]
        let router = CatchRecordRouter()
        let sut = makeSUT(router: router, draft: draft)
        sut.selection = CatchLocationNearestAreasViewModel.otherOptionID

        sut.submit()

        XCTAssertEqual(
            router.path,
            [.catchLocationManualEntry(gear: .seineNets, vessel: vessel, referenceNumber: referenceNumber)]
        )
        XCTAssertNil(draft.gearCatches.first?.statisticalArea)
    }

    // MARK: - Pre-fill on resume (see ADR-0015 decision #1)

    func test_loadAreas_prefillsSelectionFromDraftGearCatch_whenAreaIsInLoadedList() async {
        let draft = CatchRecordDraft()
        draft.departurePort = PortOption(name: "Plymouth", coordinate: plymouth)
        draft.gearCatches = [GearCatch(gear: .seineNets, statisticalArea: "38E86")]
        let sut = makeSUT(router: CatchRecordRouter(), draft: draft)

        await sut.loadAreas()

        XCTAssertEqual(sut.selection, "38E86")
    }

    func test_loadAreas_withRecordedArea_notInLoadedList_leavesSelectionNil() async {
        let draft = CatchRecordDraft()
        draft.departurePort = PortOption(name: "Plymouth", coordinate: plymouth)
        draft.gearCatches = [GearCatch(gear: .seineNets, statisticalArea: "99Z99")]
        let sut = makeSUT(router: CatchRecordRouter(), draft: draft)

        await sut.loadAreas()

        XCTAssertNil(sut.selection)
    }
}
