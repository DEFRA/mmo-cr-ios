import Foundation
import SwiftData

/// A lightweight summary of a persisted, not-yet-submitted local draft, used to render a Home
/// "Unsent" row without decoding its full payload (see ADR-0014/0015). Placeholder text for any
/// uncaptured field (`vessel`/`tripEndDate` are `nil` until the corresponding journey screen has
/// been completed) is applied by the caller (`SubmissionRow.unsentDraft(_:)`), not here.
nonisolated struct UnsentDraftSummary: Identifiable, Hashable, Sendable {
    let localID: UUID
    let vessel: String?
    let tripEndDate: Date?
    let lastEditedAt: Date

    var id: UUID { localID }
}

/// Persists the in-progress "Create a catch record" journey (`CatchRecordDraft`) on-device, so an
/// Unsent record survives app termination and can be resumed later (see ADR-0014).
///
/// API-shaped like the other stub seams in this app (`FavouritePortsProviding`, etc. — ADR-0004):
/// a protocol first, so the real SwiftData-backed implementation and an in-memory test/preview
/// fake are interchangeable without changing call sites. `@MainActor` because every call site
/// already holds `CatchRecordDraft`/`CatchRecordRouter` on the main actor — this avoids introducing
/// a second, cross-actor isolation domain purely for persistence.
@MainActor
protocol CatchRecordDraftStoring {
    /// Saves (inserting or updating) the current state of `draft`, keyed by `draft.localID`.
    func save(_ draft: CatchRecordDraft) async throws
    /// Loads the full, resumable payload for a previously-saved draft, or `nil` if none exists
    /// (e.g. already deleted).
    func loadDraft(localID: UUID) async throws -> CatchRecordDraftPayload?
    /// Permanently deletes a persisted draft (used for both explicit "Delete" and once a draft has
    /// been successfully submitted — see `SubmissionConfirmationViewModel`).
    func deleteDraft(localID: UUID) async throws
    /// Every persisted draft not yet submitted, for Home's "Unsent" rows.
    func allUnsentDrafts() async throws -> [UnsentDraftSummary]
}

/// SwiftData-backed `CatchRecordDraftStoring`.
///
/// Stores one `CatchRecordEntity` per `localID`. Data-at-rest posture: the app's shared
/// `ModelContainer` is device-local only (no `CloudKit` mirroring) — see ADR-0014 for the full
/// rationale and the file-protection level applied at container creation.
@MainActor
final class SwiftDataCatchRecordDraftStore: CatchRecordDraftStoring {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func save(_ draft: CatchRecordDraft) async throws {
        let localID = draft.localID
        let payloadData = try JSONEncoder().encode(draft.payload)
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { $0.localID == localID }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.payload = payloadData
            existing.vessel = draft.vessel
            existing.tripEndDate = draft.returnDate
            existing.lastEditedAt = Date()
        } else {
            let entity = CatchRecordEntity(
                localID: localID,
                lastEditedAt: Date(),
                vessel: draft.vessel,
                tripEndDate: draft.returnDate,
                payload: payloadData
            )
            modelContext.insert(entity)
        }
        try modelContext.save()
    }

    func loadDraft(localID: UUID) async throws -> CatchRecordDraftPayload? {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { $0.localID == localID }
        )
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return try JSONDecoder().decode(CatchRecordDraftPayload.self, from: entity.payload)
    }

    func deleteDraft(localID: UUID) async throws {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { $0.localID == localID }
        )
        guard let existing = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    func allUnsentDrafts() async throws -> [UnsentDraftSummary] {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { !$0.isSubmitted },
            sortBy: [SortDescriptor(\.lastEditedAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map {
            UnsentDraftSummary(localID: $0.localID, vessel: $0.vessel, tripEndDate: $0.tripEndDate, lastEditedAt: $0.lastEditedAt)
        }
    }
}

/// In-memory `CatchRecordDraftStoring` fake for previews and unit tests — no SwiftData
/// `ModelContainer` required, so view-model tests stay fast and hermetic.
@MainActor
final class InMemoryCatchRecordDraftStore: CatchRecordDraftStoring {

    private struct Record {
        var payload: CatchRecordDraftPayload
        var vessel: String?
        var tripEndDate: Date?
        var lastEditedAt: Date
        var isSubmitted: Bool
    }

    private nonisolated(unsafe) var records: [UUID: Record] = [:]

    /// `nonisolated` so this store can be used as a default parameter value from any isolation
    /// context (e.g. non-`@MainActor` `View`/view-model initializers), mirroring
    /// `CatchRecordDraft`'s `nonisolated init()`.
    nonisolated init(seed: [UUID: CatchRecordDraftPayload] = [:]) {
        let now = Date()
        records = seed.mapValues {
            Record(payload: $0, vessel: $0.vessel, tripEndDate: $0.returnDate, lastEditedAt: now, isSubmitted: false)
        }
    }

    func save(_ draft: CatchRecordDraft) async throws {
        records[draft.localID] = Record(
            payload: draft.payload,
            vessel: draft.vessel,
            tripEndDate: draft.returnDate,
            lastEditedAt: Date(),
            isSubmitted: records[draft.localID]?.isSubmitted ?? false
        )
    }

    func loadDraft(localID: UUID) async throws -> CatchRecordDraftPayload? {
        records[localID]?.payload
    }

    func deleteDraft(localID: UUID) async throws {
        records[localID] = nil
    }

    func allUnsentDrafts() async throws -> [UnsentDraftSummary] {
        records
            .filter { !$0.value.isSubmitted }
            .map { UnsentDraftSummary(localID: $0.key, vessel: $0.value.vessel, tripEndDate: $0.value.tripEndDate, lastEditedAt: $0.value.lastEditedAt) }
            .sorted { $0.lastEditedAt > $1.lastEditedAt }
    }
}
