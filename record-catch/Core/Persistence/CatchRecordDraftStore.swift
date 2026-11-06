import Foundation
import SwiftData

/// A lightweight summary of a persisted local draft, used to render a Home row without decoding
/// its full payload (see ADR-0014/0015). Covers both a still-in-progress/Unsent draft and one that
/// has since been marked submitted (`isSubmitted`) — see `CatchRecordDraftStoring.allRecords()`.
/// Placeholder text for any uncaptured field (`vessel`/`tripEndDate` are `nil` until the
/// corresponding journey screen has been completed) is applied by the caller
/// (`SubmissionRow.unsentDraft(_:)`), not here.
nonisolated struct UnsentDraftSummary: Identifiable, Hashable, Sendable {
    let localID: UUID
    let vessel: String?
    let tripEndDate: Date?
    let lastEditedAt: Date
    /// Denormalised checkpoint for this draft (see `CatchRecordEntity.checkpointRawValue`,
    /// BR-SUB-010/AC12). Falls back to `.vessel` for any row persisted before this field existed.
    let checkpoint: CatchRecordCheckpoint
    /// Whether this draft has been successfully submitted (see `CatchRecordEntity.isSubmitted`).
    /// `false` for every row returned by `allUnsentDrafts()`; may be `true` for a row returned by
    /// `allRecords()`. Drives the Home row's status (`RecordsMerging.row(for:)`).
    let isSubmitted: Bool

    init(
        localID: UUID,
        vessel: String?,
        tripEndDate: Date?,
        lastEditedAt: Date,
        checkpointRawValue: Int? = nil,
        isSubmitted: Bool = false
    ) {
        self.localID = localID
        self.vessel = vessel
        self.tripEndDate = tripEndDate
        self.lastEditedAt = lastEditedAt
        self.checkpoint = checkpointRawValue.flatMap(CatchRecordCheckpoint.init(rawValue:)) ?? .vessel
        self.isSubmitted = isSubmitted
    }

    var id: UUID { localID }

    /// Whether this draft has reached Check your answers at least once — the "Complete Not
    /// Submitted" state distinct from still being "Draft" in progress (see BR-SUB-010/AC12). The
    /// visible status-tag rename this backs is deferred pending a design decision (see the plan).
    var isComplete: Bool { checkpoint >= .checkYourAnswers }
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
    /// Permanently deletes a persisted draft (used only for the user's explicit "Delete" action on
    /// `DraftActionView` — see ADR-0014 decision #5). A successfully submitted draft is retained
    /// and flagged via `markSubmitted(localID:)` instead, so it keeps showing on Home.
    func deleteDraft(localID: UUID) async throws
    /// Flags a persisted draft as submitted (see `CatchRecordEntity.isSubmitted`), without deleting
    /// it, once `CatchRecordSubmissionServicing.submit(referenceNumber:)` has succeeded (see
    /// `CheckYourAnswersViewModel`). A no-op if `localID` is unknown. Leaves every other field
    /// (`vessel`, `tripEndDate`, `payload`, `checkpointRawValue`) untouched, so the record keeps
    /// showing on Home — now as `.submitted` rather than `.unsent` (see `RecordsMerging.row(for:)`)
    /// — with its correct, already-captured trip-end date, until a real backend becomes the source
    /// of truth for it (see ADR-0014/0015).
    func markSubmitted(localID: UUID) async throws
    /// Every persisted draft not yet submitted, for Home's "Unsent" rows.
    func allUnsentDrafts() async throws -> [UnsentDraftSummary]
    /// Every persisted local draft, submitted or not — Home's full local contribution to the
    /// merged records list (see `MergingRecordsRepository`). Unlike `allUnsentDrafts()`, this
    /// includes rows flagged by `markSubmitted(localID:)` so a completed catch record keeps
    /// appearing (as `.submitted`) once the stub/real server's own copy also exists.
    func allRecords() async throws -> [UnsentDraftSummary]
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
            existing.checkpointRawValue = draft.checkpoint.rawValue
        } else {
            let entity = CatchRecordEntity(
                localID: localID,
                lastEditedAt: Date(),
                vessel: draft.vessel,
                tripEndDate: draft.returnDate,
                payload: payloadData,
                checkpointRawValue: draft.checkpoint.rawValue
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

    func markSubmitted(localID: UUID) async throws {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { $0.localID == localID }
        )
        guard let existing = try modelContext.fetch(descriptor).first else { return }
        existing.isSubmitted = true
        try modelContext.save()
    }

    func allUnsentDrafts() async throws -> [UnsentDraftSummary] {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { !$0.isSubmitted },
            sortBy: [SortDescriptor(\.lastEditedAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map(Self.summary(for:))
    }

    func allRecords() async throws -> [UnsentDraftSummary] {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            sortBy: [SortDescriptor(\.lastEditedAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map(Self.summary(for:))
    }

    private static func summary(for entity: CatchRecordEntity) -> UnsentDraftSummary {
        UnsentDraftSummary(
            localID: entity.localID,
            vessel: entity.vessel,
            tripEndDate: entity.tripEndDate,
            lastEditedAt: entity.lastEditedAt,
            checkpointRawValue: entity.checkpointRawValue,
            isSubmitted: entity.isSubmitted
        )
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
        var checkpoint: CatchRecordCheckpoint
    }

    private nonisolated(unsafe) var records: [UUID: Record] = [:]

    /// `nonisolated` so this store can be used as a default parameter value from any isolation
    /// context (e.g. non-`@MainActor` `View`/view-model initializers), mirroring
    /// `CatchRecordDraft`'s `nonisolated init()`.
    nonisolated init(seed: [UUID: CatchRecordDraftPayload] = [:]) {
        let now = Date()
        records = seed.mapValues {
            Record(
                payload: $0,
                vessel: $0.vessel,
                tripEndDate: $0.returnDate,
                lastEditedAt: now,
                isSubmitted: false,
                checkpoint: $0.checkpoint
            )
        }
    }

    func save(_ draft: CatchRecordDraft) async throws {
        records[draft.localID] = Record(
            payload: draft.payload,
            vessel: draft.vessel,
            tripEndDate: draft.returnDate,
            lastEditedAt: Date(),
            isSubmitted: records[draft.localID]?.isSubmitted ?? false,
            checkpoint: draft.checkpoint
        )
    }

    func loadDraft(localID: UUID) async throws -> CatchRecordDraftPayload? {
        records[localID]?.payload
    }

    func deleteDraft(localID: UUID) async throws {
        records[localID] = nil
    }

    func markSubmitted(localID: UUID) async throws {
        guard records[localID] != nil else { return }
        records[localID]?.isSubmitted = true
    }

    func allUnsentDrafts() async throws -> [UnsentDraftSummary] {
        records
            .filter { !$0.value.isSubmitted }
            .map(Self.summary(for:))
            .sorted { $0.lastEditedAt > $1.lastEditedAt }
    }

    func allRecords() async throws -> [UnsentDraftSummary] {
        records
            .map(Self.summary(for:))
            .sorted { $0.lastEditedAt > $1.lastEditedAt }
    }

    private static func summary(for entry: (key: UUID, value: Record)) -> UnsentDraftSummary {
        UnsentDraftSummary(
            localID: entry.key,
            vessel: entry.value.vessel,
            tripEndDate: entry.value.tripEndDate,
            lastEditedAt: entry.value.lastEditedAt,
            checkpointRawValue: entry.value.checkpoint.rawValue,
            isSubmitted: entry.value.isSubmitted
        )
    }
}
