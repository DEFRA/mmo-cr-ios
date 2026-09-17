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

    // MARK: - Resume (see ADR-0014/0015 — "Complete" restarts from the beginning, pre-filled)

    func test_resumeDraft_withNoLocalID_pushesSelectVessel_leavesDraftUntouched() async {
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        let sut = DraftActionViewModel(row: row, router: router, draft: draft) // row.localID is nil

        await sut.resumeDraft()

        XCTAssertEqual(router.path, [.selectVessel])
        XCTAssertNil(draft.vessel)
    }

    func test_resumeDraft_withPersistedDraft_loadsPayloadIntoSharedDraft_andPushesSelectVessel() async {
        let localID = UUID()
        let rowWithLocalID = record_catch.SubmissionRow(
            dateText: "—", vesselName: "—", status: .unsent, createdBy: "You", localID: localID
        )
        let seededDraft = CatchRecordDraft(localID: localID)
        seededDraft.vessel = "ACHILLES"
        seededDraft.departurePort = PortOption(name: "Hastings")
        let store = InMemoryCatchRecordDraftStore(seed: [localID: seededDraft.payload])

        let router = CatchRecordRouter()
        let sharedDraft = CatchRecordDraft()
        let sut = DraftActionViewModel(row: rowWithLocalID, router: router, draft: sharedDraft, draftStore: store)

        await sut.resumeDraft()

        XCTAssertEqual(sharedDraft.vessel, "ACHILLES")
        XCTAssertEqual(sharedDraft.departurePort, PortOption(name: "Hastings"))
        XCTAssertEqual(router.path, [.selectVessel])
    }

    func test_resumeDraft_withUnknownLocalID_startsBlank_stillPushesSelectVessel() async {
        let rowWithLocalID = record_catch.SubmissionRow(
            dateText: "—", vesselName: "—", status: .unsent, createdBy: "You", localID: UUID()
        )
        let router = CatchRecordRouter()
        let draft = CatchRecordDraft()
        let sut = DraftActionViewModel(row: rowWithLocalID, router: router, draft: draft, draftStore: InMemoryCatchRecordDraftStore())

        await sut.resumeDraft()

        XCTAssertNil(draft.vessel)
        XCTAssertEqual(router.path, [.selectVessel])
    }

    // MARK: - Delete removes the persisted draft (see ADR-0014)

    func test_confirmDelete_withLocalID_removesPersistedDraft() async {
        let localID = UUID()
        let rowWithLocalID = record_catch.SubmissionRow(
            dateText: "—", vesselName: "—", status: .unsent, createdBy: "You", localID: localID
        )
        let store = InMemoryCatchRecordDraftStore(seed: [localID: CatchRecordDraft(localID: localID).payload])
        let router = CatchRecordRouter()
        let sut = DraftActionViewModel(row: rowWithLocalID, router: router, draftStore: store)
        sut.selection = .delete
        sut.submit()

        sut.confirmDelete()
        // Allow the fire-and-forget deletion Task to run.
        try? await Task.sleep(nanoseconds: 10_000_000)

        let remaining = try? await store.loadDraft(localID: localID)
        XCTAssertNil(remaining ?? nil)
    }
}
