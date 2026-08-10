import XCTest
@testable import record_catch

@MainActor
final class DraftActionViewModelTests: XCTestCase {

    private let row = record_catch.SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith")

    func test_initialState_hasNoSelectionAndNoError() {
        let sut = DraftActionViewModel(row: row, router: CatchRecordRouter())
        XCTAssertNil(sut.selection)
        XCTAssertNil(sut.errorKey)
        XCTAssertFalse(sut.showDeleteConfirmation)
    }

    func test_submit_withNoSelection_setsError_andDoesNotRoute() {
        let router = CatchRecordRouter()
        let sut = DraftActionViewModel(row: row, router: router)

        sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.draftAction.validation.none")
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_withCompleteSelected_pushesSelectVessel() {
        let router = CatchRecordRouter()
        let sut = DraftActionViewModel(row: row, router: router)
        sut.selection = .complete

        sut.submit()

        XCTAssertNil(sut.errorKey)
        XCTAssertEqual(router.path, [.selectVessel])
    }

    func test_submit_withDeleteSelected_showsConfirmation_doesNotRouteYet() {
        let router = CatchRecordRouter()
        let sut = DraftActionViewModel(row: row, router: router)
        sut.selection = .delete

        sut.submit()

        XCTAssertTrue(sut.showDeleteConfirmation)
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_confirmDelete_dismissesDialog_andPopsToRoot() {
        let router = CatchRecordRouter()
        router.push(.selectVessel) // simulate non-empty stack
        let sut = DraftActionViewModel(row: row, router: router)
        sut.selection = .delete
        sut.submit()

        sut.confirmDelete()

        XCTAssertFalse(sut.showDeleteConfirmation)
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_cancelDelete_dismissesDialog_selectionUnchanged_noRouting() {
        let router = CatchRecordRouter()
        let sut = DraftActionViewModel(row: row, router: router)
        sut.selection = .delete
        sut.submit()

        sut.cancelDelete()

        XCTAssertFalse(sut.showDeleteConfirmation)
        XCTAssertEqual(sut.selection, .delete)
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_errorKey_beforeSubmit_isNilEvenWithoutSelection() {
        let sut = DraftActionViewModel(row: row, router: CatchRecordRouter())
        XCTAssertNil(sut.errorKey)
    }
}
