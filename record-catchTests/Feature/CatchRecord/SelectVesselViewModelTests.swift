import XCTest
@testable import record_catch

private struct StubVesselProvider: VesselProviding {
    let vessels: [String]
}

@MainActor
final class SelectVesselViewModelTests: XCTestCase {

    func test_init_exposesVesselsFromProvider() {
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: ["A", "B"]))
        XCTAssertEqual(sut.vessels, ["A", "B"])
    }

    func test_staticVesselProvider_returnsAchillesAndHercules() {
        XCTAssertEqual(StaticVesselProvider().vessels, ["ACHILLES", "HERCULES"])
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = SelectVesselViewModel(router: router, provider: StaticVesselProvider())

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.selectVessel.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withSelection_pushesTripStartedToday_withPlaceholderReferenceNumber_whenNoRSSNumberKnown() {
        // StubVesselProvider has no RSS number for any vessel (returns nil, the default
        // VesselProviding.rssNumber(forVesselNamed:) implementation) — the placeholder reference
        // is the correct, safe fallback rather than blocking the journey (ADR-0026).
        let router = CatchRecordRouter()
        let sut = SelectVesselViewModel(router: router, provider: StubVesselProvider(vessels: ["ACHILLES"]))
        sut.selection = "ACHILLES"

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.tripStartedToday(vessel: "ACHILLES", referenceNumber: SelectVesselViewModel.placeholderReferenceNumber)]
        )
    }

    // MARK: - Catch record reference generation (ADR-0026)

    func test_submit_withSelection_generatesReference_fromVesselRSSNumber() {
        let router = CatchRecordRouter()
        let fixedDate = Date(timeIntervalSince1970: 1_793_200_815) // 2026-11-11T10:00:00Z UK time
        let generator = CatchRecordReferenceGenerator(now: { fixedDate })
        let sut = SelectVesselViewModel(router: router, provider: StaticVesselProvider(), referenceGenerator: generator)
        sut.selection = "ACHILLES"

        sut.submit()

        let expected = try! generator.generate(rssNumber: "A12345")
        XCTAssertEqual(router.path, [.tripStartedToday(vessel: "ACHILLES", referenceNumber: expected)])
        XCTAssertNotEqual(expected, SelectVesselViewModel.placeholderReferenceNumber)
    }

    func test_submit_writesGeneratedReferenceIntoDraft() {
        let draft = CatchRecordDraft()
        let generator = CatchRecordReferenceGenerator(now: { Date(timeIntervalSince1970: 1_793_200_815) })
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StaticVesselProvider(), draft: draft, referenceGenerator: generator)
        sut.selection = "ACHILLES"

        sut.submit()

        XCTAssertEqual(draft.catchRecordReference, try! generator.generate(rssNumber: "A12345"))
    }

    func test_submit_resumedDraft_keepsExistingReference_ratherThanRegenerating() {
        let draft = CatchRecordDraft()
        draft.catchRecordReference = "A12345-01012026-090000"
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StaticVesselProvider(), draft: draft)
        sut.selection = "ACHILLES"

        sut.submit()

        XCTAssertEqual(draft.catchRecordReference, "A12345-01012026-090000")
    }

    // MARK: - Vessel is a one-time step (see ADR-0013 amendment)

    func test_submit_withSelection_replacesSelectVessel_ratherThanPushingOnTop() {
        let router = CatchRecordRouter()
        router.startNew() // path == [.selectVessel]
        let sut = SelectVesselViewModel(router: router, provider: StubVesselProvider(vessels: ["ACHILLES"]))
        sut.selection = "ACHILLES"

        sut.submit()

        // .selectVessel is replaced, not left behind the next screen — so Back from here leaves
        // the journey rather than re-opening vessel selection.
        XCTAssertEqual(
            router.path,
            [.tripStartedToday(vessel: "ACHILLES", referenceNumber: SelectVesselViewModel.placeholderReferenceNumber)]
        )
    }

    func test_errorKey_beforeSubmit_isNil() {
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StaticVesselProvider())
        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Draft capture

    func test_submit_withSelection_writesVesselIntoDraft() {
        let draft = CatchRecordDraft()
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StaticVesselProvider(), draft: draft)
        sut.selection = "ACHILLES"

        sut.submit()

        XCTAssertEqual(draft.vessel, "ACHILLES")
    }

    // MARK: - Pre-fill on resume (see ADR-0015 decision #1)

    func test_init_prefillsSelectionFromDraftVessel() {
        let draft = CatchRecordDraft()
        draft.vessel = "HERCULES"

        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StaticVesselProvider(), draft: draft)

        XCTAssertEqual(sut.selection, "HERCULES")
    }

    func test_init_withNoDraftVessel_leavesSelectionNil() {
        let sut = SelectVesselViewModel(router: CatchRecordRouter(), provider: StaticVesselProvider(), draft: CatchRecordDraft())

        XCTAssertNil(sut.selection)
    }
}
