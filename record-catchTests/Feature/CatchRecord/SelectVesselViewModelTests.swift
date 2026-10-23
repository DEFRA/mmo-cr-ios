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

    func test_submit_withSelection_pushesTripStartedToday_withPlaceholderReferenceNumber() {
        let router = CatchRecordRouter()
        let sut = SelectVesselViewModel(router: router, provider: StaticVesselProvider())
        sut.selection = "ACHILLES"

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(
            router.path,
            [.tripStartedToday(vessel: "ACHILLES", referenceNumber: SelectVesselViewModel.placeholderReferenceNumber)]
        )
    }

    // MARK: - Vessel is a one-time step (see ADR-0013 amendment)

    func test_submit_withSelection_replacesSelectVessel_ratherThanPushingOnTop() {
        let router = CatchRecordRouter()
        router.startNew() // path == [.selectVessel]
        let sut = SelectVesselViewModel(router: router, provider: StaticVesselProvider())
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
