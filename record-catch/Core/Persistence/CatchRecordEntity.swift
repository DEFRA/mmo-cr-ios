import Foundation
import SwiftData

/// The on-device, SwiftData-persisted representation of an in-progress or completed
/// "Create a catch record" journey (see ADR-0014).
///
/// Deliberately a thin, denormalised shell: `vessel`/`tripEndDate` are duplicated out of `payload`
/// purely so Home's list can render without decoding JSON for every row, while `payload` (a JSON
/// encoding of `CatchRecordDraftPayload`) remains the single, full-fidelity source of truth used to
/// resume a draft (`CatchRecordDraftStoring.loadDraft(localID:)`). `localID` is the stable identity
/// threaded through `CatchRecordDraft`/`SubmissionRow` so a Home row, a resumed journey and this
/// stored record all refer to the same draft.
///
/// Not synced to iCloud and not shared with any other on-device store — offline-first, local
/// source of truth per the DEFRA mobile standards (see ADR-0014's data-at-rest posture).
@Model
final class CatchRecordEntity {
    @Attribute(.unique) var localID: UUID
    var lastEditedAt: Date
    /// Whether this record has been submitted. A submitted record is retained (not deleted) and
    /// excluded from the Unsent list (`CatchRecordDraftStoring.allUnsentDrafts()`), but still
    /// included — as `.submitted` — in the full local contribution to Home's merged list
    /// (`CatchRecordDraftStoring.allRecords()`, `RecordsMerging.row(for:)`) until a real backend
    /// exists and becomes the source of truth for it (see ADR-0014/0015).
    var isSubmitted: Bool
    /// Denormalised for cheap Home-row rendering (see the note above). `nil` until captured.
    var vessel: String?
    /// Denormalised copy of `CatchRecordDraftPayload.catchRecordReference` (see ADR-0026) — the
    /// client-generated catch record reference, created once a vessel is confirmed. `nil` for any
    /// row persisted before this field existed (mirrors `checkpointRawValue` below); such a draft
    /// is given a reference the next time it is resumed (see `DraftActionViewModel.resumeDraft()`).
    var catchRecordReference: String?
    /// Denormalised for cheap Home-row rendering. `nil` until captured.
    var tripEndDate: Date?
    /// JSON-encoded `CatchRecordDraftPayload` — the full-fidelity, resumable snapshot of the draft.
    var payload: Data
    /// Denormalised copy of `CatchRecordDraft.checkpoint.rawValue` (see `CatchRecordCheckpoint`),
    /// so Home can distinguish an in-progress draft from one that has reached Check your answers
    /// without decoding `payload` (mirrors the `vessel`/`tripEndDate` denormalisation above — see
    /// BR-SUB-010/AC12). `nil` for any row persisted before this field existed; `UnsentDraftSummary`
    /// falls back to `.vessel` (the safe "still in progress" default) in that case. Declared
    /// optional so adding this attribute is a lightweight SwiftData migration — see
    /// `SchemaMigrationPlan`/`VersionedSchema` in Apple's SwiftData docs.
    var checkpointRawValue: Int?

    // MARK: - Submission queue (ADR-0028)
    //
    // Every field below is optional, added after the first release of this entity, so every
    // already-persisted row (predating the queue) decodes unchanged — a lightweight SwiftData
    // migration, mirroring `checkpointRawValue` above. Together they let
    // `CatchRecordStatusResolver` distinguish all four app-managed statuses (Draft, Complete/
    // Pending, Submitted, Amended — AC1–AC8) from only two backend-persisted facts
    // (`backendStatusRaw`, `submissionCount`) plus the transient `queueStateRaw`.

    /// `CatchRecordQueueState.rawValue` — whether this record is currently queued/sending to the
    /// backend. `nil`/`0` (`.none`) for a record that has never been queued, or whose last queue
    /// attempt has already resolved (success or permanent failure).
    var queueStateRaw: Int?
    /// The last backend-persisted status known for this record (`PersistedCatchRecordStatus.
    /// rawValue`, e.g. `"DRAFT"`/`"SUBMITTED"`). `nil` for a record never yet synced with the
    /// backend. Falls back to deriving from the legacy `isSubmitted` flag for any row written
    /// before this field existed (see `CatchRecordDraftStoring.markSubmitted(localID:)`, kept for
    /// backward compatibility) — see `CatchRecordSubmissionCoordinator`/`RecordsMerging`.
    var backendStatusRaw: String?
    /// How many times this record has been successfully submitted (AC5 — `> 1` once amended).
    /// `nil` is treated as `1` when `backendStatusRaw` indicates a submitted record (the common
    /// "submitted exactly once, never amended" case), and as `0` otherwise.
    var submissionCount: Int?
    /// The Catch Recording Service's own id for this record, once `createDraft`/`startEdit` has
    /// returned one (see `CatchRecordSubmissionCoordinator`). `nil` until the first successful
    /// create call.
    var serverID: String?
    /// The optimistic-concurrency version last known for `serverID` (the service's `If-Match`
    /// precondition — see ADR-0025 §5). Updated after every successful create/replace/submit call.
    var serverVersion: Int?
    /// The `Idempotency-Key` used for the current (or most recent) submission attempt cycle.
    /// Generated once when first queued and reused across retries of the *same* attempt cycle, so
    /// a retried create/submit call is provably the same logical request if it reaches the backend
    /// twice (e.g. a response lost after the backend already applied it). Cleared once the cycle
    /// resolves (success or permanent failure) so the *next* submission attempt (e.g. a future
    /// amendment) gets a fresh key.
    var idempotencyKey: String?
    /// The machine-readable `APIError`/`APIErrorDetails.code` from the most recent failed attempt,
    /// for diagnostics only (DEFRA "log errors" requirement) — never the server's free-text
    /// `message`, which must never be logged or surfaced (see ADR-0025 §1, security instructions).
    var lastErrorCode: String?
    /// When the most recent submission attempt (success or failure) completed, for backoff/
    /// diagnostics.
    var lastAttemptAt: Date?

    init(
        localID: UUID,
        lastEditedAt: Date,
        isSubmitted: Bool = false,
        summary: CatchRecordEntitySummary = CatchRecordEntitySummary(),
        payload: Data,
        checkpointRawValue: Int? = nil
    ) {
        self.localID = localID
        self.lastEditedAt = lastEditedAt
        self.isSubmitted = isSubmitted
        self.vessel = summary.vessel
        self.catchRecordReference = summary.catchRecordReference
        self.tripEndDate = summary.tripEndDate
        self.payload = payload
        self.checkpointRawValue = checkpointRawValue
    }
}

/// Groups `CatchRecordEntity`'s three denormalised, cheap-to-render Home-row fields (see the
/// entity's own doc comment) into one injectable value — keeps the initializer's parameter count
/// under Sonar's authorised limit (`swift:S107`) while leaving each field individually settable.
struct CatchRecordEntitySummary {
    var vessel: String?
    var catchRecordReference: String?
    var tripEndDate: Date?

    init(vessel: String? = nil, catchRecordReference: String? = nil, tripEndDate: Date? = nil) {
        self.vessel = vessel
        self.catchRecordReference = catchRecordReference
        self.tripEndDate = tripEndDate
    }
}
