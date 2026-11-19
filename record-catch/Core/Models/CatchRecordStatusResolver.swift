import Foundation

/// Whether a locally-persisted catch record is currently queued for submission to the backend
/// (see ADR-0028, the submission queue).
///
/// `Int`-backed so it round-trips as `CatchRecordEntity.queueStateRaw` with the same lightweight
/// SwiftData migration pattern as `checkpointRawValue` (ADR-0014) — an optional stored property
/// with a safe fallback for any row persisted before this field existed.
nonisolated enum CatchRecordQueueState: Int, Codable, Sendable {
    /// Not queued — either never submitted, or the backend has already accepted the submission.
    case none = 0
    /// Waiting for connectivity (or its turn) before the queue attempts to send it.
    case pending = 1
    /// A send attempt is currently in flight.
    case sending = 2
}

/// Resolves the **UI-managed** display status (`SubmissionStatus`) for a catch record from the
/// handful of **backend-managed** facts the device holds about it (see ADR-0028 and the business
/// rules it implements — AC1–AC8):
///
/// | Status            | Backend persisted? | Rule |
/// |--------------------|---------------------|------|
/// | Draft              | ✅ (`DRAFT`)        | Started but not yet successfully submitted. |
/// | Submitted          | ✅ (`SUBMITTED`)    | Successfully submitted and received. |
/// | Complete/Pending   | ❌ (UI only)        | Completed on-device, queued or sending — mobile only. |
/// | Amended            | ❌ (UI only)        | Previously submitted, since re-submitted. |
///
/// The backend only ever persists `Draft`/`Submitted` (AC7); `Complete/Pending` and `Amended` are
/// derived here, purely from on-device state, and are never sent to or read as a persisted backend
/// value (AC8). Kept as a free-standing, pure `enum` (no stored state) so every rule is a single,
/// trivially unit-testable function — mirrors `CatchRecordRouting`/`RecordsMerging`.
nonisolated enum CatchRecordStatusResolver {

    /// - Parameters:
    ///   - queueState: Whether this record is currently queued/sending (see
    ///     `CatchRecordSubmissionCoordinator`). Always wins over the backend status — a record
    ///     that is mid-(re-)submission is **Complete/Pending** regardless of what the backend last
    ///     reported (AC3/AC4).
    ///   - backendStatus: The last backend-persisted status known for this record, or `nil` for a
    ///     record that has never been synced with the backend at all (a brand new, in-progress
    ///     draft). The backend's own `COMPLETE` value (a third, legacy/extra value the Catch
    ///     Recording Service's schema allows outside the two AC7 permits) is treated exactly like
    ///     `SUBMITTED` — see ADR-0028 "Known backend status gap".
    ///   - submissionCount: How many times this record has been successfully submitted. `0`/`1`
    ///     for a first, never-repeated submission; `> 1` once it has been edited and re-submitted
    ///     at least once (AC5). Ignored unless `backendStatus` indicates a submitted record.
    static func status(
        queueState: CatchRecordQueueState,
        backendStatus: PersistedCatchRecordStatus?,
        submissionCount: Int
    ) -> SubmissionStatus {
        guard queueState == .none else { return .completePending }

        switch backendStatus {
        case .submitted, .complete:
            return submissionCount > 1 ? .amended : .submitted
        case .draft, nil:
            return .unsent
        }
    }
}
