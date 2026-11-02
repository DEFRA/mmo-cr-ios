import XCTest
@testable import record_catch

@MainActor
final class CatchRecordRouterTests: XCTestCase {

    private let draftRow = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith")

    func test_init_pathIsEmpty() {
        let sut = CatchRecordRouter()
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_startFromDraft_setsPathToSingleDraftActionRoute() {
        let sut = CatchRecordRouter()

        sut.startFromDraft(draftRow)

        XCTAssertEqual(sut.path, [.draftAction(draftRow)])
    }

    func test_startNew_setsPathToSelectVessel() {
        let sut = CatchRecordRouter()

        sut.startNew()

        XCTAssertEqual(sut.path, [.selectVessel])
    }

    func test_push_appendsRoute() {
        let sut = CatchRecordRouter()
        sut.startNew()

        sut.push(.tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF"))

        XCTAssertEqual(sut.path, [.selectVessel, .tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF")])
    }

    func test_pop_removesTopRoute_returningToPreviousScreen() {
        let sut = CatchRecordRouter()
        sut.startNew()
        sut.push(.tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF"))

        sut.pop()

        XCTAssertEqual(sut.path, [.selectVessel])
    }

    func test_pop_whenAtRoot_isNoOp() {
        let sut = CatchRecordRouter()

        sut.pop()

        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_popToRoot_clearsPath() {
        let sut = CatchRecordRouter()
        sut.startNew()
        sut.push(.tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF"))

        sut.popToRoot()

        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_setPath_replacesWholePath() {
        let sut = CatchRecordRouter()
        sut.startNew()

        sut.setPath([.submissionSuccess(referenceNumber: "REF")])

        XCTAssertEqual(sut.path, [.submissionSuccess(referenceNumber: "REF")])
    }

    // MARK: - replaceCurrent (see ADR-0013 amendment — vessel selection is a one-time step)

    func test_replaceCurrent_swapsTheTopRoute_leavingEarlierRoutesUntouched() {
        let sut = CatchRecordRouter()
        sut.startFromDraft(draftRow)
        sut.push(.selectVessel)

        sut.replaceCurrent(with: .tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF"))

        XCTAssertEqual(sut.path, [.draftAction(draftRow), .tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF")])
    }

    func test_replaceCurrent_whenPathIsEmpty_pushesAsSoleEntry() {
        let sut = CatchRecordRouter()

        sut.replaceCurrent(with: .tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF"))

        XCTAssertEqual(sut.path, [.tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF")])
    }

    // MARK: - shouldPersistDraft (see ADR-0014 §4, amended)

    func test_shouldPersistDraft_withEmptyPath_isFalse() {
        XCTAssertFalse(CatchRecordRouter.shouldPersistDraft(path: [], vessel: "ACHILLES"))
    }

    func test_shouldPersistDraft_withNoVesselYet_isFalse() {
        XCTAssertFalse(
            CatchRecordRouter.shouldPersistDraft(
                path: [.tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF")],
                vessel: nil
            )
        )
    }

    func test_shouldPersistDraft_whileStillShowingSelectVessel_isFalse() {
        XCTAssertFalse(CatchRecordRouter.shouldPersistDraft(path: [.selectVessel], vessel: "ACHILLES"))
    }

    func test_shouldPersistDraft_onTheScreenAfterVesselSelection_isTrue() {
        XCTAssertTrue(
            CatchRecordRouter.shouldPersistDraft(
                path: [.tripStartedToday(vessel: "ACHILLES", referenceNumber: "REF")],
                vessel: "ACHILLES"
            )
        )
    }

    func test_shouldPersistDraft_onSubmissionSuccess_isFalse() {
        XCTAssertFalse(
            CatchRecordRouter.shouldPersistDraft(
                path: [.submissionSuccess(referenceNumber: "REF")],
                vessel: "ACHILLES"
            )
        )
    }
}
