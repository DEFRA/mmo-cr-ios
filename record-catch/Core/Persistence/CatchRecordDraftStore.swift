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
    /// `allRecords()`. Kept for backward compatibility (`markSubmitted(localID:)`); superseded for
    /// status display by `displayStatus` below (see ADR-0028).
    let isSubmitted: Bool
    /// Whether this record is currently queued/sending to the backend (see
    /// `CatchRecordSubmissionCoordinator`, ADR-0028). `.none` for any row persisted before the
    /// submission queue existed.
    let queueState: CatchRecordQueueState
    /// The last backend-persisted status known for this record (see
    /// `CatchRecordEntity.backendStatusRaw`). `nil` for a row that predates the queue and was never
    /// submitted; `displayStatus` falls back to `isSubmitted` in that case.
    let backendStatusRaw: String?
    /// How many times this record has been successfully submitted (AC5). `nil` for a row that
    /// predates this field; `displayStatus` falls back to `isSubmitted ? 1 : 0` in that case.
    let submissionCount: Int?

    /// The three ADR-0028 queue fields grouped into one value, keeping `UnsentDraftSummary.init`
    /// within the project's max-parameter-count limit (SonarCloud `swift:S107`) rather than passing
    /// `queueStateRaw`/`backendStatusRaw`/`submissionCount` as three separate parameters.
    nonisolated struct QueueSnapshot: Hashable, Sendable {
        let queueStateRaw: Int?
        let backendStatusRaw: String?
        let submissionCount: Int?

        /// The safe default for any row that predates the submission queue — `displayStatus` falls
        /// back to `isSubmitted` in that case.
        static let none = QueueSnapshot(queueStateRaw: nil, backendStatusRaw: nil, submissionCount: nil)
    }

    init(
        localID: UUID,
        vessel: String?,
        tripEndDate: Date?,
        lastEditedAt: Date,
        checkpointRawValue: Int? = nil,
        isSubmitted: Bool = false,
        queueSnapshot: QueueSnapshot = .none
    ) {
        self.localID = localID
        self.vessel = vessel
        self.tripEndDate = tripEndDate
        self.lastEditedAt = lastEditedAt
        self.checkpoint = checkpointRawValue.flatMap(CatchRecordCheckpoint.init(rawValue:)) ?? .vessel
        self.isSubmitted = isSubmitted
        self.queueState = queueSnapshot.queueStateRaw.flatMap(CatchRecordQueueState.init(rawValue:)) ?? .none
        self.backendStatusRaw = queueSnapshot.backendStatusRaw
        self.submissionCount = queueSnapshot.submissionCount
    }

    var id: UUID { localID }

    /// Whether this draft has reached Check your answers at least once — the "Complete Not
    /// Submitted" state distinct from still being "Draft" in progress (see BR-SUB-010/AC12). The
    /// visible status-tag rename this backs is deferred pending a design decision (see the plan).
    var isComplete: Bool { checkpoint >= .checkYourAnswers }

    /// The app-managed display status for this record (AC1–AC8), via `CatchRecordStatusResolver`.
    /// Falls back to the legacy `isSubmitted` flag for any row persisted before the queue fields
    /// existed, so every already-persisted record keeps resolving to exactly the status it showed
    /// before this change (`.submitted`/`.unsent`, never `.completePending`/`.amended`) until it is
    /// next queued or submitted through the new path.
    var displayStatus: SubmissionStatus {
        let resolvedBackendStatus = backendStatusRaw.flatMap(PersistedCatchRecordStatus.init(rawValue:))
            ?? (isSubmitted ? .submitted : nil)
        let resolvedSubmissionCount = submissionCount ?? (isSubmitted ? 1 : 0)
        return CatchRecordStatusResolver.status(
            queueState: queueState,
            backendStatus: resolvedBackendStatus,
            submissionCount: resolvedSubmissionCount
        )
    }
}

/// A persisted record's server-side submission progress (see `CatchRecordSubmissionCoordinator`,
/// ADR-0028) — the identifiers a resumed/retried submission attempt needs so it never has to
/// restart from `createDraft` once a `serverID` already exists.
nonisolated struct CatchRecordSubmissionProgress: Sendable {
    /// The Catch Recording Service's id for this record, once known.
    let serverID: String?
    /// The optimistic-concurrency version last known for `serverID`.
    let serverVersion: Int?
    /// The `Idempotency-Key` for the current submission attempt cycle (see
    /// `CatchRecordEntity.idempotencyKey`).
    let idempotencyKey: String
}

/// Persists the in-progress "Create a catch record" journey (`CatchRecordDraft`) on-device, so an
/// Unsent record survives app termination and can be resumed later (see ADR-0014), and tracks its
/// submission-queue progress once "Accept and submit trip details" is tapped (see ADR-0028).
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
    /// it. Kept for backward compatibility with existing call sites/tests; equivalent to calling
    /// `markSubmissionSucceeded(localID:submittedVersion:)` with no known server version. Prefer
    /// the submission-queue methods below for anything going through the real connector.
    func markSubmitted(localID: UUID) async throws
    /// Every persisted draft not yet submitted, for Home's "Unsent" (Draft) rows.
    func allUnsentDrafts() async throws -> [UnsentDraftSummary]
    /// Every persisted local draft, submitted or not — Home's full local contribution to the
    /// merged records list (see `MergingRecordsRepository`). Unlike `allUnsentDrafts()`, this
    /// includes rows flagged by `markSubmitted(localID:)` so a completed catch record keeps
    /// appearing (as `.submitted`) once the stub/real server's own copy also exists.
    func allRecords() async throws -> [UnsentDraftSummary]

    // MARK: - Submission queue (ADR-0028)

    /// Saves `draft` (as `save(_:)` does) and marks it queued for submission
    /// (`CatchRecordQueueState.pending`), generating a fresh `Idempotency-Key` for this attempt
    /// cycle if one is not already in progress. Called the moment "Accept and submit trip
    /// details" is tapped, **before** any network attempt — so the record is never lost even if
    /// the app is killed before a single byte is sent (offline-first — see
    /// `CheckYourAnswersViewModel.submit(isOnline:)`).
    func enqueueForSubmission(_ draft: CatchRecordDraft) async throws
    /// Marks a queued record as currently being sent (`CatchRecordQueueState.sending`), so a
    /// concurrent trigger (e.g. connectivity restored firing mid-flush) does not attempt to send
    /// it twice (see `CatchRecordSubmissionCoordinator`).
    func markSending(localID: UUID) async throws
    /// The server identifiers/idempotency key known so far for a queued record, or `nil` if
    /// `localID` is unknown or was never queued.
    func submissionProgress(localID: UUID) async throws -> CatchRecordSubmissionProgress?
    /// Records the server id/version returned by `createDraft`/`replaceCatchRecord`, without
    /// otherwise changing the record's queue/backend status.
    func recordServerProgress(localID: UUID, serverID: String, version: Int) async throws
    /// Marks a record's submission as having been accepted by the backend: clears the queue
    /// state, records the backend status as `.submitted`, increments `submissionCount` (so a
    /// second successful submission of the same record resolves to **Amended** — AC5), and clears
    /// the attempt's idempotency key (a future re-submission gets a fresh one). A no-op if
    /// `localID` is unknown.
    func markSubmissionSucceeded(localID: UUID, submittedVersion: Int?) async throws
    /// Marks a submission attempt as having failed. A **retryable** failure (`permanent == false`)
    /// leaves the record queued (`CatchRecordQueueState.pending`) so a later trigger retries it;
    /// a **permanent** failure (validation, mapping, configuration — never worth retrying
    /// automatically) clears the queue state, so the record falls back to showing as **Draft**
    /// (AC7) rather than being stuck showing Complete/Pending forever. `errorCode` is a machine-
    /// readable diagnostic only (never server free-text — see `CatchRecordEntity.lastErrorCode`).
    func markSubmissionFailed(localID: UUID, permanent: Bool, errorCode: String) async throws
    /// Every currently-queued record's `localID` (pending or still marked sending from an
    /// interrupted previous attempt), oldest first, for `CatchRecordSubmissionCoordinator.
    /// flushPending()` to retry in order.
    func pendingSubmissionLocalIDs() async throws -> [UUID]
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
            existing.catchRecordReference = draft.catchRecordReference
            existing.tripEndDate = draft.returnDate
            existing.lastEditedAt = Date()
            existing.checkpointRawValue = draft.checkpoint.rawValue
        } else {
            let entity = CatchRecordEntity(
                localID: localID,
                lastEditedAt: Date(),
                summary: CatchRecordEntitySummary(
                    vessel: draft.vessel,
                    catchRecordReference: draft.catchRecordReference,
                    tripEndDate: draft.returnDate
                ),
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
        try await markSubmissionSucceeded(localID: localID, submittedVersion: nil)
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

    // MARK: - Submission queue

    func enqueueForSubmission(_ draft: CatchRecordDraft) async throws {
        try await save(draft)
        let localID = draft.localID
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { $0.localID == localID }
        )
        guard let existing = try modelContext.fetch(descriptor).first else { return }
        existing.queueStateRaw = CatchRecordQueueState.pending.rawValue
        if existing.idempotencyKey == nil {
            existing.idempotencyKey = UUID().uuidString
        }
        existing.lastErrorCode = nil
        try modelContext.save()
    }

    func markSending(localID: UUID) async throws {
        try await updateEntity(localID: localID) { $0.queueStateRaw = CatchRecordQueueState.sending.rawValue }
    }

    func submissionProgress(localID: UUID) async throws -> CatchRecordSubmissionProgress? {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { $0.localID == localID }
        )
        guard let existing = try modelContext.fetch(descriptor).first,
              let idempotencyKey = existing.idempotencyKey else { return nil }
        return CatchRecordSubmissionProgress(
            serverID: existing.serverID,
            serverVersion: existing.serverVersion,
            idempotencyKey: idempotencyKey
        )
    }

    func recordServerProgress(localID: UUID, serverID: String, version: Int) async throws {
        try await updateEntity(localID: localID) {
            $0.serverID = serverID
            $0.serverVersion = version
        }
    }

    func markSubmissionSucceeded(localID: UUID, submittedVersion: Int?) async throws {
        try await updateEntity(localID: localID) { entity in
            entity.isSubmitted = true
            entity.backendStatusRaw = PersistedCatchRecordStatus.submitted.rawValue
            entity.submissionCount = (entity.submissionCount ?? 0) + 1
            entity.queueStateRaw = CatchRecordQueueState.none.rawValue
            entity.idempotencyKey = nil
            entity.lastErrorCode = nil
            entity.lastAttemptAt = Date()
            if let submittedVersion {
                entity.serverVersion = submittedVersion
            }
        }
    }

    func markSubmissionFailed(localID: UUID, permanent: Bool, errorCode: String) async throws {
        try await updateEntity(localID: localID) { entity in
            entity.lastErrorCode = errorCode
            entity.lastAttemptAt = Date()
            if permanent {
                entity.queueStateRaw = CatchRecordQueueState.none.rawValue
                entity.idempotencyKey = nil
            } else {
                entity.queueStateRaw = CatchRecordQueueState.pending.rawValue
            }
        }
    }

    func pendingSubmissionLocalIDs() async throws -> [UUID] {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { $0.queueStateRaw != nil && $0.queueStateRaw != 0 },
            sortBy: [SortDescriptor(\.lastEditedAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(\.localID)
    }

    private func updateEntity(localID: UUID, _ mutate: (CatchRecordEntity) -> Void) async throws {
        let descriptor = FetchDescriptor<CatchRecordEntity>(
            predicate: #Predicate { $0.localID == localID }
        )
        guard let existing = try modelContext.fetch(descriptor).first else { return }
        mutate(existing)
        try modelContext.save()
    }

    private static func summary(for entity: CatchRecordEntity) -> UnsentDraftSummary {
        UnsentDraftSummary(
            localID: entity.localID,
            vessel: entity.vessel,
            tripEndDate: entity.tripEndDate,
            lastEditedAt: entity.lastEditedAt,
            checkpointRawValue: entity.checkpointRawValue,
            isSubmitted: entity.isSubmitted,
            queueSnapshot: UnsentDraftSummary.QueueSnapshot(
                queueStateRaw: entity.queueStateRaw,
                backendStatusRaw: entity.backendStatusRaw,
                submissionCount: entity.submissionCount
            )
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
        var queueState: CatchRecordQueueState = .none
        var backendStatusRaw: String?
        var submissionCount: Int?
        var serverID: String?
        var serverVersion: Int?
        var idempotencyKey: String?
        var lastErrorCode: String?
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
        var record = records[draft.localID] ?? Record(
            payload: draft.payload,
            vessel: draft.vessel,
            tripEndDate: draft.returnDate,
            lastEditedAt: Date(),
            isSubmitted: false,
            checkpoint: draft.checkpoint
        )
        record.payload = draft.payload
        record.vessel = draft.vessel
        record.tripEndDate = draft.returnDate
        record.lastEditedAt = Date()
        record.checkpoint = draft.checkpoint
        records[draft.localID] = record
    }

    func loadDraft(localID: UUID) async throws -> CatchRecordDraftPayload? {
        records[localID]?.payload
    }

    func deleteDraft(localID: UUID) async throws {
        records[localID] = nil
    }

    func markSubmitted(localID: UUID) async throws {
        try await markSubmissionSucceeded(localID: localID, submittedVersion: nil)
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

    // MARK: - Submission queue

    func enqueueForSubmission(_ draft: CatchRecordDraft) async throws {
        try await save(draft)
        guard var record = records[draft.localID] else { return }
        record.queueState = .pending
        if record.idempotencyKey == nil {
            record.idempotencyKey = UUID().uuidString
        }
        record.lastErrorCode = nil
        records[draft.localID] = record
    }

    func markSending(localID: UUID) async throws {
        records[localID]?.queueState = .sending
    }

    func submissionProgress(localID: UUID) async throws -> CatchRecordSubmissionProgress? {
        guard let record = records[localID], let idempotencyKey = record.idempotencyKey else { return nil }
        return CatchRecordSubmissionProgress(
            serverID: record.serverID,
            serverVersion: record.serverVersion,
            idempotencyKey: idempotencyKey
        )
    }

    func recordServerProgress(localID: UUID, serverID: String, version: Int) async throws {
        records[localID]?.serverID = serverID
        records[localID]?.serverVersion = version
    }

    func markSubmissionSucceeded(localID: UUID, submittedVersion: Int?) async throws {
        guard var record = records[localID] else { return }
        record.isSubmitted = true
        record.backendStatusRaw = PersistedCatchRecordStatus.submitted.rawValue
        record.submissionCount = (record.submissionCount ?? 0) + 1
        record.queueState = .none
        record.idempotencyKey = nil
        record.lastErrorCode = nil
        if let submittedVersion {
            record.serverVersion = submittedVersion
        }
        records[localID] = record
    }

    func markSubmissionFailed(localID: UUID, permanent: Bool, errorCode: String) async throws {
        guard var record = records[localID] else { return }
        record.lastErrorCode = errorCode
        if permanent {
            record.queueState = .none
            record.idempotencyKey = nil
        } else {
            record.queueState = .pending
        }
        records[localID] = record
    }

    func pendingSubmissionLocalIDs() async throws -> [UUID] {
        records
            .filter { $0.value.queueState != .none }
            .sorted { $0.value.lastEditedAt < $1.value.lastEditedAt }
            .map(\.key)
    }

    private static func summary(for entry: (key: UUID, value: Record)) -> UnsentDraftSummary {
        UnsentDraftSummary(
            localID: entry.key,
            vessel: entry.value.vessel,
            tripEndDate: entry.value.tripEndDate,
            lastEditedAt: entry.value.lastEditedAt,
            checkpointRawValue: entry.value.checkpoint.rawValue,
            isSubmitted: entry.value.isSubmitted,
            queueSnapshot: UnsentDraftSummary.QueueSnapshot(
                queueStateRaw: entry.value.queueState.rawValue,
                backendStatusRaw: entry.value.backendStatusRaw,
                submissionCount: entry.value.submissionCount
            )
        )
    }
}
