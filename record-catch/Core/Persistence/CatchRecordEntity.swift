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
    /// Whether this record has been submitted. Submitted records are removed from the Unsent list
    /// (see `CatchRecordDraftStoring.allUnsentDrafts()`); this app currently deletes on submission
    /// rather than retaining submitted rows locally (see ADR-0014 — the server is the source of
    /// truth for submitted/amended/late records in this phase).
    var isSubmitted: Bool
    /// Denormalised for cheap Home-row rendering (see the note above). `nil` until captured.
    var vessel: String?
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
        tripEndDate: Date?,
        payload: Data,
        checkpointRawValue: Int? = nil
    ) {
        self.localID = localID
        self.lastEditedAt = lastEditedAt
        self.isSubmitted = isSubmitted
        self.vessel = vessel
        self.tripEndDate = tripEndDate
        self.payload = payload
        self.checkpointRawValue = checkpointRawValue
    }
}
