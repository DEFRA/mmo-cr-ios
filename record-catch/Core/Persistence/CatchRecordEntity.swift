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

    init(
        localID: UUID,
        lastEditedAt: Date,
        isSubmitted: Bool = false,
        vessel: String?,
        catchRecordReference: String? = nil,
        tripEndDate: Date?,
        payload: Data,
        checkpointRawValue: Int? = nil
    ) {
        self.localID = localID
        self.lastEditedAt = lastEditedAt
        self.isSubmitted = isSubmitted
        self.vessel = vessel
        self.catchRecordReference = catchRecordReference
        self.tripEndDate = tripEndDate
        self.payload = payload
        self.checkpointRawValue = checkpointRawValue
    }
}
