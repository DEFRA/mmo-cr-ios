import XCTest
@testable import record_catch

@MainActor
final class SelectVesselViewModelTests: XCTestCase {

    private let achilles = VesselOption(id: "v-achilles", name: "ACHILLES", displayName: "ACHILLES PH1234", registrationNumber: "A12345")
    private let seaSpray = VesselOption(id: "v-seaspray", name: "SEA SPRAY", displayName: "SEA SPRAY BM45")

    // MARK: - Loading

    func test_init_startsInLoadingState() {
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: [achilles]))
        XCTAssertEqual(sut.state, .loading)
    }

    func test_load_withVessels_movesToLoadedState() async {
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: [achilles, seaSpray]))

        await sut.load()

        XCTAssertEqual(sut.state, .loaded([achilles, seaSpray]))
    }

    func test_load_withNoVessels_movesToEmptyState() async {
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: []))

        await sut.load()

        XCTAssertEqual(sut.state, .empty)
    }

    // MARK: - Submit

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = SelectVesselViewModel(router: router, provider: StubVesselProvider(vessels: [achilles]))

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.selectVessel.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_beforeLoadCompletes_doesNotRoute() {
        // `state` is still `.loading` (never loaded) — submit must not crash or route.
        let router = CatchRecordRouter()
        let sut = SelectVesselViewModel(router: router, provider: StubVesselProvider(vessels: [achilles]))
        sut.selectionID = achilles.id

        sut.submit()

        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withSelection_pushesTripStartedToday_withPlaceholderReferenceNumber_whenNoRSSNumberKnown() async {
        // seaSpray has no RSS number — the placeholder reference is the correct, safe fallback
        // rather than blocking the journey (ADR-0026).
        let router = CatchRecordRouter()
        let sut = SelectVesselViewModel(router: router, provider: StubVesselProvider(vessels: [seaSpray]))
        await sut.load()
        sut.selectionID = seaSpray.id

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.tripStartedToday(vessel: "SEA SPRAY", referenceNumber: SelectVesselViewModel.placeholderReferenceNumber)]
        )
    }

    // MARK: - Catch record reference generation (ADR-0026)

    func test_submit_withSelection_generatesReference_fromVesselRSSNumber() async {
        let router = CatchRecordRouter()
        let fixedDate = Date(timeIntervalSince1970: 1_793_200_815) // 2026-11-11T10:00:00Z UK time
        let generator = CatchRecordReferenceGenerator(now: { fixedDate })
        let sut = SelectVesselViewModel(router: router, provider: StubVesselProvider(vessels: [achilles]), referenceGenerator: generator)
        await sut.load()
        sut.selectionID = achilles.id

        sut.submit()

        let expected = try! generator.generate(rssNumber: "A12345")
        XCTAssertEqual(router.path, [.tripStartedToday(vessel: "ACHILLES", referenceNumber: expected)])
        XCTAssertNotEqual(expected, SelectVesselViewModel.placeholderReferenceNumber)
    }

    func test_submit_writesGeneratedReferenceAndSnapshotIntoDraft() async {
        let draft = CatchRecordDraft()
        let generator = CatchRecordReferenceGenerator(now: { Date(timeIntervalSince1970: 1_793_200_815) })
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: [achilles]), draft: draft, referenceGenerator: generator)
        await sut.load()
        sut.selectionID = achilles.id

        sut.submit()

        XCTAssertEqual(draft.catchRecordReference, try! generator.generate(rssNumber: "A12345"))
        XCTAssertEqual(draft.vesselSnapshot, achilles)
        XCTAssertEqual(draft.vessel, "ACHILLES")
    }

    func test_submit_resumedDraft_keepsExistingReference_ratherThanRegenerating() async {
        let draft = CatchRecordDraft()
        draft.catchRecordReference = "A12345-01012026-090000"
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: [achilles]), draft: draft)
        await sut.load()
        sut.selectionID = achilles.id

        sut.submit()

        XCTAssertEqual(draft.catchRecordReference, "A12345-01012026-090000")
    }

    // MARK: - Vessel is a one-time step (see ADR-0013 amendment)

    func test_submit_withSelection_replacesSelectVessel_ratherThanPushingOnTop() async {
        let router = CatchRecordRouter()
        router.startNew() // path == [.selectVessel]
        let sut = SelectVesselViewModel(router: router, provider: StubVesselProvider(vessels: [achilles]))
        await sut.load()
        sut.selectionID = achilles.id

        sut.submit()

        // .selectVessel is replaced, not left behind the next screen — so Back from here leaves
        // the journey rather than re-opening vessel selection.
        XCTAssertEqual(router.path.count, 1)
        if case .tripStartedToday(let vessel, _) = router.path.first {
            XCTAssertEqual(vessel, "ACHILLES")
        } else {
            XCTFail("Expected .tripStartedToday")
        }
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: [achilles]))
        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Pre-fill on resume (see ADR-0015 decision #1)

    func test_load_prefillsSelectionFromDraftVesselSnapshot() async {
        let draft = CatchRecordDraft()
        draft.vesselSnapshot = seaSpray
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: [achilles, seaSpray]), draft: draft)

        XCTAssertEqual(sut.selectionID, seaSpray.id) // set synchronously in init, from the snapshot
        await sut.load()
        XCTAssertEqual(sut.selectionID, seaSpray.id)
    }

    func test_load_withOnlyAVesselName_resolvesSelectionByName() async {
        // Mirrors a draft persisted before `vesselSnapshot` existed — only `draft.vessel` is set.
        let draft = CatchRecordDraft()
        draft.vessel = "SEA SPRAY"
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: [achilles, seaSpray]), draft: draft)

        await sut.load()

        XCTAssertEqual(sut.selectionID, seaSpray.id)
    }

    func test_load_withNoDraftVessel_leavesSelectionNil() async {
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: [achilles]), draft: CatchRecordDraft())

        await sut.load()

        XCTAssertNil(sut.selectionID)
    }
}
