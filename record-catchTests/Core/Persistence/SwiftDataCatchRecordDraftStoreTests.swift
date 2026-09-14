import XCTest
import SwiftData
@testable import record_catch

/// Exercises `SwiftDataCatchRecordDraftStore` against a real, in-memory `ModelContainer` (rather
/// than `InMemoryCatchRecordDraftStore`'s hand-rolled dictionary fake), so the actual SwiftData
/// fetch/insert/delete/save calls in `CatchRecordDraftStore.swift` — and `CatchRecordEntity`'s
/// initializer — are covered (see ADR-0014). `isStoredInMemoryOnly: true` keeps this hermetic and
/// fast: nothing touches disk.
@MainActor
final class SwiftDataCatchRecordDraftStoreTests: XCTestCase {

    private func makeStore() throws -> SwiftDataCatchRecordDraftStore {
        let container = try ModelContainer(
            for: CatchRecordEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataCatchRecordDraftStore(modelContext: ModelContext(container))
    }

    // MARK: - Save / load round trip

    func test_save_thenLoadDraft_returnsThePersistedPayload() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.returnDate = Date()
        draft.gearCatches = [GearCatch(gear: .seineNets, statisticalArea: "38E96")]

        try await store.save(draft)
        let loaded = try await store.loadDraft(localID: draft.localID)

        XCTAssertEqual(loaded, draft.payload)
    }

    func test_save_calledTwiceForSameLocalID_updatesRatherThanDuplicates() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await store.save(draft)

        draft.vessel = "HERCULES"
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.vessel, "HERCULES")
    }

    func test_loadDraft_forUnknownLocalID_returnsNil() async throws {
        let store = try makeStore()
        let loaded = try await store.loadDraft(localID: UUID())
        XCTAssertNil(loaded)
    }

    // MARK: - Delete

    func test_deleteDraft_removesIt_soLoadReturnsNil() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await store.save(draft)

        try await store.deleteDraft(localID: draft.localID)

        let loaded = try await store.loadDraft(localID: draft.localID)
        XCTAssertNil(loaded)
    }

    func test_deleteDraft_forUnknownLocalID_isANoOp() async throws {
        let store = try makeStore()
        try await store.deleteDraft(localID: UUID()) // should not throw
    }

    // MARK: - allUnsentDrafts

    func test_allUnsentDrafts_returnsEverySavedDraft_newestFirst() async throws {
        let store = try makeStore()
        let first = CatchRecordDraft()
        first.vessel = "ACHILLES"
        try await store.save(first)

        try await Task.sleep(nanoseconds: 5_000_000) // ensures a distinct lastEditedAt

        let second = CatchRecordDraft()
        second.vessel = "HERCULES"
        try await store.save(second)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertEqual(summaries.map(\.vessel), ["HERCULES", "ACHILLES"])
    }

    func test_allUnsentDrafts_whenEmpty_returnsEmptyArray() async throws {
        let store = try makeStore()
        let summaries = try await store.allUnsentDrafts()
        XCTAssertTrue(summaries.isEmpty)
    }

    func test_allUnsentDrafts_summary_carriesVesselAndTripEndDateFromTheDraft() async throws {
        let store = try makeStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        draft.returnDate = Date()
        try await store.save(draft)

        let summaries = try await store.allUnsentDrafts()

        XCTAssertEqual(summaries.first?.localID, draft.localID)
        XCTAssertEqual(summaries.first?.vessel, draft.vessel)
        XCTAssertEqual(summaries.first?.tripEndDate, draft.returnDate)
    }
}
