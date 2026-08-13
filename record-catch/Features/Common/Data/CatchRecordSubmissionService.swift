import Foundation

/// Errors that can occur submitting a completed `CatchRecordDraft`.
///
/// Typed rather than a generic/stringly-typed error so callers can branch on the failure kind.
/// Only `.network` exists in this UI-only phase (the stub always succeeds unless told otherwise
/// in tests), but the type is shaped so a real implementation can add cases (e.g. `.validation`,
/// `.unauthorized`) without changing call sites.
enum CatchRecordSubmissionError: Error, Equatable {
    /// The submission could not reach the backend (offline, timeout, server error, ...).
    case network
}

/// Submits a completed catch record to the (not-yet-built) MMO backend.
///
/// API-shaped stub seam, mirroring the favourites providers (see ADR-0004): the real network
/// implementation can be swapped in later without changing `SubmissionConfirmationViewModel` or
/// its tests. There is no live network call in this phase — see the module README's "UI-only
/// phase" note.
nonisolated protocol CatchRecordSubmissionServicing: Sendable {
    /// Submits `referenceNumber` for the current draft, returning once accepted or throwing
    /// `CatchRecordSubmissionError` if it could not be submitted (e.g. offline).
    func submit(referenceNumber: String) async throws
}

/// In-memory, always-succeeding stub used while there is no real submission API.
///
/// Kept deliberately trivial: this phase is UI-only, so the "submission" is a fixed short delay
/// (to give the UI a realistic loading state to demo/test) rather than a real network call.
nonisolated struct StubCatchRecordSubmissionService: CatchRecordSubmissionServicing {

    init() {}

    func submit(referenceNumber: String) async throws {
        try? await Task.sleep(nanoseconds: 300_000_000)
    }
}
