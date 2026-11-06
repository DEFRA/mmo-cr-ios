import XCTest
@testable import record_catch

@MainActor
final class RecordsRepositoryTests: XCTestCase {

    private let now = Date()

    // MARK: - Pure merge/ordering

    func test_merge_ordersEveryRowNewestFirstBySortDate() {
        let older = record_catch.SubmissionRow(dateText: "1 Jan 2020", vesselName: "ACHILLES", status: .submitted, createdBy: "J.Smith", sortDate: now.addingTimeInterval(-1_000))
        let newer = record_catch.SubmissionRow(dateText: "2 Jan 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "You", sortDate: now)

        let merged = RecordsMerging.merge(draftRows: [older], serverRows: [newer])

        XCTAssertEqual(merged.map(\.dateText), ["2 Jan 2020", "1 Jan 2020"])
    }

    func test_merge_withNoRows_returnsEmpty() {
        XCTAssertTrue(RecordsMerging.merge(draftRows: [], serverRows: []).isEmpty)
    }

    // MARK: - Row factory (placeholders for uncaptured fields — ADR-0015 decision #6)

    func test_row_forSummaryWithEveryFieldCaptured_rendersRealValues() {
        let localID = UUID()
        let tripEndDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2020, month: 11, day: 20))!
        let summary = UnsentDraftSummary(localID: localID, vessel: "ACHILLES", tripEndDate: tripEndDate, lastEditedAt: now)

        let row = RecordsMerging.row(for: summary)

        XCTAssertEqual(row.vesselName, "ACHILLES")
        XCTAssertEqual(row.dateText, "20 Nov 2020")
        XCTAssertEqual(row.status, .unsent)
        XCTAssertEqual(row.localID, localID)
    }

    func test_row_forSummaryWithNoCapturedFields_rendersPlaceholders() {
        let summary = UnsentDraftSummary(localID: UUID(), vessel: nil, tripEndDate: nil, lastEditedAt: now)

        let row = RecordsMerging.row(for: summary)

        XCTAssertEqual(row.vesselName, RecordsMerging.placeholder)
        XCTAssertEqual(row.dateText, RecordsMerging.placeholder)
        XCTAssertEqual(row.createdBy, RecordsMerging.localCreatedByPlaceholder)
    }

    // A submitted local draft is retained (not deleted — see `CheckYourAnswersViewModel` and
    // ADR-0014/0015 amendment) and must keep showing on Home, now as `.submitted` with its
    // already-captured date, and with no `localID` (it is no longer resumable/deletable via
    // `DraftActionView` — see `CatchRecordRouting.entryRoute(for:)`).
    func test_row_forASubmittedSummary_rendersSubmittedStatus_withNoResumableLocalID() {
        let localID = UUID()
        let tripEndDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 27))!
        let summary = UnsentDraftSummary(
            localID: localID,
            vessel: "ACHILLES",
            tripEndDate: tripEndDate,
            lastEditedAt: now,
            isSubmitted: true
        )

        let row = RecordsMerging.row(for: summary)

        XCTAssertEqual(row.vesselName, "ACHILLES")
        XCTAssertEqual(row.dateText, "27 Jul 2026")
        XCTAssertEqual(row.status, .submitted)
        XCTAssertNil(row.localID)
    }

    // MARK: - End-to-end via the repository

    func test_records_mergesLocalDraftsAndServerRecords() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await draftStore.save(draft)

        let repository = MergingRecordsRepository(draftStore: draftStore, serverRecords: StubServerRecordsProvider())

        let rows = try await repository.records()

        // `StubServerRecordsProvider` returns no fixtures (there is no real backend yet — see
        // ADR-0015), so the merged list is exactly the real local Unsent draft: no placeholder
        // submitted/amended/late rows.
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.contains { $0.status == .unsent && $0.vesselName == "ACHILLES" })
    }

    func test_records_withNoLocalDrafts_returnsOnlyServerRecords() async throws {
        let repository = MergingRecordsRepository(draftStore: InMemoryCatchRecordDraftStore(), serverRecords: StubServerRecordsProvider())

        let rows = try await repository.records()

        // No local drafts and no server records yet (stub returns none) → empty list, which
        // `HomeViewModel` surfaces as its explicit Empty state.
        XCTAssertTrue(rows.isEmpty)
    }

    // Regression test for the bug where a completed/submitted catch record vanished from Home: it
    // was deleted locally on successful submission and the (stub) server never returns it either
    // (see ADR-0014/0015 amendment, `CheckYourAnswersViewModel.submit(isOnline:)`).
    func test_records_includesASubmittedLocalDraft_withSubmittedStatus_soItDoesNotVanishFromHome() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.returnDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 27))!
        try await draftStore.save(draft)
        try await draftStore.markSubmitted(localID: draft.localID)

        let repository = MergingRecordsRepository(draftStore: draftStore, serverRecords: StubServerRecordsProvider())

        let rows = try await repository.records()

        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.status, .submitted)
        XCTAssertEqual(row.vesselName, "ACHILLES")
        XCTAssertEqual(row.dateText, "27 Jul 2026")
    }
}
