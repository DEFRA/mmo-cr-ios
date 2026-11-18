import Foundation
import SwiftUI

/// The result of attempting to submit one queued catch record right now (see
/// `CatchRecordSubmissionQueuing.submitNow(localID:timeout:)`).
nonisolated enum CatchRecordSubmissionOutcome: Equatable, Sendable {
    /// The backend accepted the submission. Safe to show the green "submitted" confirmation.
    case submitted
    /// Not yet submitted — either genuinely offline, a retryable failure, or the attempt did not
    /// finish within its timeout. The record stays queued and will be retried automatically; the
    /// caller must show the truthful "saved on this device" screen, never the submitted one
    /// (BR-SUB-008/AC10/AC11).
    case queued
    /// A non-retryable failure (validation, mapping, configuration). The record is no longer
    /// queued and now shows as **Draft** — the caller should surface an inline, recoverable error
    /// rather than navigating onward.
    case failedPermanently
}

/// Seam for queueing and sending catch-record submissions, so view models/screens never talk to
/// `CatchRecordServicing` directly (see ADR-0028). `@MainActor` — every call site already holds
/// `CatchRecordDraft`/the draft store on the main actor.
@MainActor
protocol CatchRecordSubmissionQueuing: AnyObject {
    /// Persists `draft` and marks it queued for submission (see
    /// `CatchRecordDraftStoring.enqueueForSubmission(_:)`). Always called **before** any network
    /// attempt, so a record is never lost even if the app is killed immediately afterwards.
    func enqueue(_ draft: CatchRecordDraft) async
    /// Attempts to send the already-queued record for `localID` right now, waiting up to
    /// `timeout` seconds. Only ever attempts a send while online; returns `.queued` immediately
    /// otherwise.
    func submitNow(localID: UUID, timeout: TimeInterval) async -> CatchRecordSubmissionOutcome
    /// Attempts every currently-queued record, in order. Used by the app-level triggers
    /// (connectivity restored, foreground, reaching Home) — see `RecordCatchApp`.
    func flushPending() async
}

/// Always-queues, never-sends `CatchRecordSubmissionQueuing` stub — the safe default wherever no
/// real queue has been configured (e.g. an unconfigured preview), mirroring
/// `StubConnectivityMonitor`'s "treat as a safe default" convention. Records enqueued here simply
/// stay **Complete/Pending** until a real `CatchRecordSubmissionCoordinator` is present.
@MainActor
final class StubCatchRecordSubmissionQueue: CatchRecordSubmissionQueuing {
    private let draftStore: CatchRecordDraftStoring

    /// `nonisolated` so this stub can be used as a default parameter value from any isolation
    /// context (e.g. `CheckYourAnswersView`'s non-`@MainActor` `init`), mirroring
    /// `InMemoryCatchRecordDraftStore`'s own `nonisolated init`.
    nonisolated init(draftStore: CatchRecordDraftStoring = InMemoryCatchRecordDraftStore()) {
        self.draftStore = draftStore
    }

    func enqueue(_ draft: CatchRecordDraft) async {
        try? await draftStore.enqueueForSubmission(draft)
    }

    func submitNow(localID: UUID, timeout: TimeInterval) async -> CatchRecordSubmissionOutcome {
        .queued
    }

    func flushPending() async {}
}

/// Deterministic, always-succeeding `CatchRecordSubmissionQueuing` test double — used only by UI
/// tests that need "Accept and submit trip details" to reach the real `submissionSuccess` screen
/// without depending on a reachable backend (see `UITestRootView`). Lives here, in-module,
/// mirroring every other `Stub*` seam (`StubConnectivityMonitor`, etc. — ADR-0004).
@MainActor
final class AlwaysSucceedingCatchRecordSubmissionQueue: CatchRecordSubmissionQueuing {
    private let draftStore: CatchRecordDraftStoring

    nonisolated init(draftStore: CatchRecordDraftStoring = InMemoryCatchRecordDraftStore()) {
        self.draftStore = draftStore
    }

    func enqueue(_ draft: CatchRecordDraft) async {
        try? await draftStore.enqueueForSubmission(draft)
    }

    func submitNow(localID: UUID, timeout: TimeInterval) async -> CatchRecordSubmissionOutcome {
        try? await draftStore.markSubmissionSucceeded(localID: localID, submittedVersion: nil)
        return .submitted
    }

    func flushPending() async {}
}

/// Coordinates the on-device submission queue (ADR-0028): every "Accept and submit trip details"
/// enqueues the record, and this type is responsible for actually sending it — immediately if
/// possible, or later once a trigger (connectivity restored, app foregrounded, Home reached) calls
/// `flushPending()`.
///
/// Mirrors `ReferenceDataSyncCoordinator`'s shape (single in-flight run, a trailing "run again"
/// flag rather than a queue of pending runs) deliberately, since both solve the same
/// "attempt best-effort background work, never pile up concurrent attempts" problem.
///
/// Each attempt follows the Catch Recording Service's documented lifecycle (ADR-0025): create the
/// draft if no server id is yet known, replace its full content, then submit — reusing the same
/// `Idempotency-Key` across retries of one attempt cycle so a retried request is provably the same
/// logical submission if the backend already applied a response that was lost in transit.
@MainActor
@Observable
final class CatchRecordSubmissionCoordinator: CatchRecordSubmissionQueuing {

    /// When the most recent `flushPending()` run completed — observed by `HomeView` to reload its
    /// list once a Complete/Pending record resolves to Submitted (AC4).
    private(set) var lastFlushCompletedAt: Date = .distantPast

    private let service: CatchRecordServicing
    private let draftStore: CatchRecordDraftStoring
    private let vesselProvider: VesselProviding
    private let isOnline: () -> Bool
    private var isFlushing = false
    private var flushAgainRequested = false

    init(
        service: CatchRecordServicing,
        draftStore: CatchRecordDraftStoring,
        vesselProvider: VesselProviding = StaticVesselProvider(),
        isOnline: @escaping () -> Bool
    ) {
        self.service = service
        self.draftStore = draftStore
        self.vesselProvider = vesselProvider
        self.isOnline = isOnline
    }

    func enqueue(_ draft: CatchRecordDraft) async {
        try? await draftStore.enqueueForSubmission(draft)
    }

    func submitNow(localID: UUID, timeout: TimeInterval = 20) async -> CatchRecordSubmissionOutcome {
        guard isOnline() else { return .queued }
        return await withTaskGroup(of: CatchRecordSubmissionOutcome?.self) { group in
            group.addTask { await self.attemptSubmission(localID: localID) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(timeout, 0) * 1_000_000_000))
                return nil
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            // The timeout branch finished first (returned `nil`): the attempt is still running in
            // the background and will complete via the normal queue/flush path — truthful, never
            // claims success it hasn't confirmed.
            return .queued
        }
    }

    func flushPending() async {
        guard isOnline() else { return }
        guard !isFlushing else {
            flushAgainRequested = true
            return
        }
        isFlushing = true
        let ids = (try? await draftStore.pendingSubmissionLocalIDs()) ?? []
        for localID in ids {
            _ = await attemptSubmission(localID: localID)
        }
        isFlushing = false
        lastFlushCompletedAt = Date()
        if flushAgainRequested {
            flushAgainRequested = false
            await flushPending()
        }
    }

    /// Runs one full create → replace → submit attempt for an already-queued record. Always
    /// resolves the queue to a definite end state (success, retryable failure left pending, or
    /// permanent failure reverted to Draft) — never leaves a record silently stuck.
    private func attemptSubmission(localID: UUID) async -> CatchRecordSubmissionOutcome {
        try? await draftStore.markSending(localID: localID)

        guard let payload = try? await draftStore.loadDraft(localID: localID) else {
            try? await draftStore.markSubmissionFailed(localID: localID, permanent: true, errorCode: "missing_local_draft")
            return .failedPermanently
        }
        guard let progress = try? await draftStore.submissionProgress(localID: localID) else {
            try? await draftStore.markSubmissionFailed(localID: localID, permanent: true, errorCode: "missing_queue_progress")
            return .failedPermanently
        }

        let replacement: CompleteReplacementPayload
        do {
            replacement = try CatchRecordPayloadMapper.map(payload: payload, vesselProvider: vesselProvider)
        } catch let mappingError as CatchRecordMappingError {
            try? await draftStore.markSubmissionFailed(localID: localID, permanent: true, errorCode: mappingError.errorCode)
            return .failedPermanently
        } catch {
            try? await draftStore.markSubmissionFailed(localID: localID, permanent: true, errorCode: "mapping_unknown_error")
            return .failedPermanently
        }

        do {
            let (serverID, version) = try await ensureServerRecord(
                localID: localID,
                progress: progress,
                payload: payload,
                replacement: replacement
            )
            _ = try await service.replaceCatchRecord(catchRecordId: serverID, expectedVersion: version, payload: replacement)
            let submission = try await service.submit(
                catchRecordId: serverID,
                expectedVersion: version,
                idempotencyKey: progress.idempotencyKey
            )
            try? await draftStore.markSubmissionSucceeded(localID: localID, submittedVersion: submission.standard.version)
            return .submitted
        } catch let apiError as APIError {
            try? await draftStore.markSubmissionFailed(
                localID: localID,
                permanent: !apiError.isRetryable,
                errorCode: apiError.errorCode ?? "unknown_api_error"
            )
            return apiError.isRetryable ? .queued : .failedPermanently
        } catch {
            try? await draftStore.markSubmissionFailed(localID: localID, permanent: true, errorCode: "submission_unknown_error")
            return .failedPermanently
        }
    }

    /// Ensures a server-side record exists for `localID`, creating one (and recording its id/
    /// version) if this is the first attempt for this submission cycle.
    private func ensureServerRecord(
        localID: UUID,
        progress: CatchRecordSubmissionProgress,
        payload: CatchRecordDraftPayload,
        replacement: CompleteReplacementPayload
    ) async throws -> (serverID: String, version: Int) {
        if let serverID = progress.serverID, let version = progress.serverVersion {
            return (serverID, version)
        }
        let created = try await service.createDraft(
            vesselId: replacement.vessel.id,
            catchRecordReference: payload.catchRecordReference,
            idempotencyKey: progress.idempotencyKey
        )
        try? await draftStore.recordServerProgress(localID: localID, serverID: created.id, version: created.version)
        return (created.id, created.version)
    }
}

private struct CatchRecordSubmissionQueueKey: EnvironmentKey {
    /// `nil` by default, mirroring `ConnectivityMonitorKey` — `CheckYourAnswersView` falls back to
    /// a safe `StubCatchRecordSubmissionQueue` when no real coordinator has been injected (e.g. an
    /// unconfigured preview), rather than requiring every call site to supply one.
    static let defaultValue: (any CatchRecordSubmissionQueuing)? = nil
}

extension EnvironmentValues {
    /// The app-wide catch-record submission queue, seeded from `CatchRecordSubmissionCoordinator`
    /// in `RecordCatchApp` (see ADR-0028).
    var catchRecordSubmissionQueue: (any CatchRecordSubmissionQueuing)? {
        get { self[CatchRecordSubmissionQueueKey.self] }
        set { self[CatchRecordSubmissionQueueKey.self] = newValue }
    }
}
