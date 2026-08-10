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

        sut.push(.tripStartedToday(referenceNumber: "REF"))

        XCTAssertEqual(sut.path, [.selectVessel, .tripStartedToday(referenceNumber: "REF")])
    }

    func test_popToRoot_clearsPath() {
        let sut = CatchRecordRouter()
        sut.startNew()
        sut.push(.tripStartedToday(referenceNumber: "REF"))

        sut.popToRoot()

        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_setPath_replacesWholePath() {
        let sut = CatchRecordRouter()
        sut.startNew()

        sut.setPath([.placeholderNextStep])

        XCTAssertEqual(sut.path, [.placeholderNextStep])
    }
}
