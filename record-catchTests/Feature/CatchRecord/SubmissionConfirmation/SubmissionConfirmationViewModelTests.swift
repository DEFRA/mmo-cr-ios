import XCTest
@testable import record_catch

/// Always-succeeding stub submission service for exercising the happy path deterministically,
/// with no real delay.
private struct StubSuccessSubmissionService: CatchRecordSubmissionServicing {
    func submit(referenceNumber: String) async throws {}
}

private struct StubFailingSubmissionService: CatchRecordSubmissionServicing {
    func submit(referenceNumber: String) async throws {
        throw CatchRecordSubmissionError.network
    }
}

/// Mutable mock so a single view model instance can be retried after a failure — the first
/// `submit()` fails, the second succeeds — to test the "clears submitFailed on retry" behaviour
/// without recreating the view model (as a real retry-after-reconnect would look).
private final class MockRetrySubmissionService: CatchRecordSubmissionServicing, @unchecked Sendable {
    var shouldFail = true

    func submit(referenceNumber: String) async throws {
        if shouldFail { throw CatchRecordSubmissionError.network }
    }
}

@MainActor
final class SubmissionConfirmationViewModelTests: XCTestCase {

    private let referenceNumber = "A1234520260727150815"

    // MARK: - Error visibility

    func test_errorKey_beforeSubmitAttempted_isNilEvenWhenUnconfirmed() {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())

        XCTAssertNil(sut.errorKey)
    }

    func test_errorKey_afterFailedSubmit_isShown() async {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())

        await sut.submit()

        XCTAssertEqual(sut.errorKey, "catchRecord.submissionConfirmation.validation.none")
    }

    func test_errorKey_afterFailedSubmit_thenConfirming_clearsError() async {
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: CatchRecordRouter())
        await sut.submit()

        sut.isConfirmed = true

        XCTAssertNil(sut.errorKey)
    }

    // MARK: - Submit routing

    func test_submit_whenNotConfirmed_doesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: router)

        await sut.submit()

        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_whenConfirmed_pushesSubmissionSuccessOntoRouter() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: router,
            submissionService: StubSuccessSubmissionService()
        )
        sut.isConfirmed = true

        await sut.submit()

        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }

    // MARK: - Submission failure (error-handling path — 100% coverage requirement)

    func test_submit_whenSubmissionServiceFails_setsSubmitFailed_andDoesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: router,
            submissionService: StubFailingSubmissionService()
        )
        sut.isConfirmed = true

        await sut.submit()

        XCTAssertTrue(sut.submitFailed)
        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_retryAfterFailure_clearsSubmitFailed_andRoutesOnSuccess() async {
        let router = CatchRecordRouter()
        let service = MockRetrySubmissionService()
        let sut = SubmissionConfirmationViewModel(referenceNumber: referenceNumber, router: router, submissionService: service)
        sut.isConfirmed = true

        await sut.submit()
        XCTAssertTrue(sut.submitFailed)
        XCTAssertTrue(router.path.isEmpty)

        // User is back online; retapping "Accept and submit trip details" now succeeds.
        service.shouldFail = false
        await sut.submit()

        XCTAssertFalse(sut.submitFailed)
        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }

    func test_isSubmitting_isFalseAfterSubmitCompletes() async {
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            submissionService: StubSuccessSubmissionService()
        )
        sut.isConfirmed = true

        await sut.submit()

        XCTAssertFalse(sut.isSubmitting)
    }

    // MARK: - Offline submission (BR-SUB-008/AC10/AC11 — no silent data loss, no false "submitted")

    /// A fail-if-called spy: proves the (stubbed) submission service is never invoked while
    /// offline — the record must not be claimed as submitted when nothing was sent.
    private struct FailIfCalledSubmissionService: CatchRecordSubmissionServicing {
        func submit(referenceNumber: String) async throws {
            XCTFail("the submission service must not be called while offline")
        }
    }

    func test_submit_whenOffline_doesNotCallTheSubmissionService_andRoutesToSubmissionSaved() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: router,
            submissionService: FailIfCalledSubmissionService()
        )
        sut.isConfirmed = true

        await sut.submit(isOnline: false)

        XCTAssertEqual(router.path, [.submissionSaved(referenceNumber: referenceNumber)])
    }

    func test_submit_whenOffline_doesNotDeleteThePersistedDraft() async throws {
        let draftStore = InMemoryCatchRecordDraftStore()
        let draft = CatchRecordDraft()
        draft.vessel = "ACHILLES"
        try await draftStore.save(draft)
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: CatchRecordRouter(),
            submissionService: FailIfCalledSubmissionService(),
            draft: draft,
            draftStore: draftStore
        )
        sut.isConfirmed = true

        await sut.submit(isOnline: false)

        let loaded = try await draftStore.loadDraft(localID: draft.localID)
        XCTAssertNotNil(loaded, "the draft must remain resumable — nothing was submitted")
    }

    func test_submit_whenOfflineAndNotConfirmed_doesNotRoute() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: router,
            submissionService: FailIfCalledSubmissionService()
        )

        await sut.submit(isOnline: false)

        XCTAssertTrue(router.path.isEmpty)
    }

    func test_submit_isOnline_defaultsToTrue_soExistingCallersAreUnaffected() async {
        let router = CatchRecordRouter()
        let sut = SubmissionConfirmationViewModel(
            referenceNumber: referenceNumber,
            router: router,
            submissionService: StubSuccessSubmissionService()
        )
        sut.isConfirmed = true

        await sut.submit() // no `isOnline:` argument — must still take the online path

        XCTAssertEqual(router.path, [.submissionSuccess(referenceNumber: referenceNumber)])
    }
}
