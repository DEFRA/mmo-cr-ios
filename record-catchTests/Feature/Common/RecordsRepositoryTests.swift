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

    // MARK: - End-to-end via the repository

    func test_records_mergesLocalDraftsAndServerRecords() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await draftStore.save(draft)

        let repository = MergingRecordsRepository(draftStore: draftStore, serverRecords: StubServerRecordsProvider())

        let rows = try await repository.records()

        XCTAssertTrue(rows.contains { $0.status == .unsent && $0.vesselName == "ACHILLES" })
        XCTAssertTrue(rows.contains { $0.status == .submitted })
        XCTAssertTrue(rows.contains { $0.status == .amended })
        XCTAssertTrue(rows.contains { $0.status == .late })
    }

    func test_records_withNoLocalDrafts_returnsOnlyServerRecords() async throws {
        let repository = MergingRecordsRepository(draftStore: InMemoryCatchRecordDraftStore(), serverRecords: StubServerRecordsProvider())

        let rows = try await repository.records()

        XCTAssertFalse(rows.contains { $0.status == .unsent })
        XCTAssertEqual(rows.count, 3)
    }
}
