//
//  CatchRecordStatusResolverTests.swift
//  record-catchTests
//
//  Covers every status-derivation rule in `CatchRecordStatusResolver` (AC1-AC8, ADR-0028). Core
//  business logic requires >=95% coverage (testing.instructions.md) — this is a pure function, so
//  every branch is enumerated directly rather than exercised indirectly through a view model.
//

import XCTest
@testable import record_catch

final class CatchRecordStatusResolverTests: XCTestCase {

    // MARK: AC1 - Draft

    func test_status_isDraft_whenNeverSubmitted_andBackendStatusIsNil() {
        let status = CatchRecordStatusResolver.status(queueState: .none, backendStatus: nil, submissionCount: 0)
        XCTAssertEqual(status, .unsent)
    }

    func test_status_isDraft_whenBackendStatusIsDraft() {
        let status = CatchRecordStatusResolver.status(queueState: .none, backendStatus: .draft, submissionCount: 0)
        XCTAssertEqual(status, .unsent)
    }

    // MARK: AC2 - Submitted

    func test_status_isSubmitted_whenBackendStatusIsSubmitted_andSubmittedOnce() {
        let status = CatchRecordStatusResolver.status(queueState: .none, backendStatus: .submitted, submissionCount: 1)
        XCTAssertEqual(status, .submitted)
    }

    func test_status_isSubmitted_whenSubmissionCountIsZero_butBackendStatusIsSubmitted() {
        // A record persisted before `submissionCount` existed (see `UnsentDraftSummary`'s
        // `nil`-falls-back-to-0 convention) must still read as Submitted, not Amended.
        let status = CatchRecordStatusResolver.status(queueState: .none, backendStatus: .submitted, submissionCount: 0)
        XCTAssertEqual(status, .submitted)
    }

    // "Known backend status gap" (ADR-0028): the backend's own extra `COMPLETE` value is treated
    // exactly like `SUBMITTED`.
    func test_status_isSubmitted_whenBackendStatusIsComplete() {
        let status = CatchRecordStatusResolver.status(queueState: .none, backendStatus: .complete, submissionCount: 1)
        XCTAssertEqual(status, .submitted)
    }

    // MARK: AC3/AC4 - Complete/Pending (mobile only), always wins over backend status

    func test_status_isCompletePending_whenQueueStateIsPending_regardlessOfBackendStatus() {
        XCTAssertEqual(
            CatchRecordStatusResolver.status(queueState: .pending, backendStatus: nil, submissionCount: 0),
            .completePending
        )
        XCTAssertEqual(
            CatchRecordStatusResolver.status(queueState: .pending, backendStatus: .draft, submissionCount: 0),
            .completePending
        )
        XCTAssertEqual(
            CatchRecordStatusResolver.status(queueState: .pending, backendStatus: .submitted, submissionCount: 1),
            .completePending
        )
    }

    func test_status_isCompletePending_whenQueueStateIsSending() {
        let status = CatchRecordStatusResolver.status(queueState: .sending, backendStatus: .submitted, submissionCount: 1)
        XCTAssertEqual(status, .completePending)
    }

    // MARK: AC5 - Amended

    func test_status_isAmended_whenSubmittedMoreThanOnce() {
        let status = CatchRecordStatusResolver.status(queueState: .none, backendStatus: .submitted, submissionCount: 2)
        XCTAssertEqual(status, .amended)
    }

    func test_status_isAmended_whenCompleteStatus_submittedMoreThanOnce() {
        let status = CatchRecordStatusResolver.status(queueState: .none, backendStatus: .complete, submissionCount: 3)
        XCTAssertEqual(status, .amended)
    }

    func test_status_amendedTransitionsBackToCompletePending_whileTheAmendmentIsInFlight() {
        // Re-submitting an already-submitted record must show Complete/Pending while queued/sending,
        // never jump straight to Amended before the backend has actually accepted it (AC4's "mid-
        // resubmission" case generalised to AC5 — queue state always wins, see the type's doc comment).
        let status = CatchRecordStatusResolver.status(queueState: .pending, backendStatus: .submitted, submissionCount: 2)
        XCTAssertEqual(status, .completePending)
    }

    // MARK: AC7 - only Draft/Submitted are ever backend-persisted values (exhaustive switch)

    func test_status_everyPersistedCatchRecordStatusCase_mapsToAUIStatus() {
        for backendStatus in [PersistedCatchRecordStatus.draft, .submitted, .complete] {
            _ = CatchRecordStatusResolver.status(queueState: .none, backendStatus: backendStatus, submissionCount: 1)
        }
        // No crash / no missing-case compile error is the assertion here — `status(queueState:
        // backendStatus:submissionCount:)`'s inner switch is exhaustive over every backend-persisted
        // status the app recognises (AC7).
    }
}
