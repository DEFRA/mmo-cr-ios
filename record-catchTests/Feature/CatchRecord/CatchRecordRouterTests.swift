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
}
