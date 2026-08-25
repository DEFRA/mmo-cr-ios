import Foundation

/// View model for the "Confirmation" screen — the final gate before submitting a completed catch
/// record, reached from "Save and continue" on Check your answers.
///
/// Requires the user to tick a single confirmation checkbox acknowledging the record is complete
/// and accurate before "Accept and submit trip details" proceeds; declining to tick it shows an
/// inline error and does not navigate. Once ticked, "Accept and submit trip details" calls the
/// (stubbed) `CatchRecordSubmissionServicing` — this is where the real submission API call will
/// happen in a future phase — and only routes on to `submissionSuccess` once it succeeds. A
/// transient/offline failure surfaces a recoverable inline error and does not navigate, matching
/// the `saveFailed` pattern used elsewhere in this module (e.g. `GearMeasurementsViewModel`).
@MainActor
@Observable
final class SubmissionConfirmationViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    var isConfirmed = false
    private(set) var didAttemptSubmit = false
    private(set) var isSubmitting = false
    /// Set when the (stubbed) submission API call fails, so the view can surface a recoverable,
    /// accessible error rather than silently discarding the attempt.
    private(set) var submitFailed = false

    private let router: CatchRecordRouter
    private let submissionService: CatchRecordSubmissionServicing

    init(
        referenceNumber: String,
        router: CatchRecordRouter,
        submissionService: CatchRecordSubmissionServicing = StubCatchRecordSubmissionService()
    ) {
        self.referenceNumber = referenceNumber
        self.router = router
        self.submissionService = submissionService
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SubmissionConfirmationValidation.errorKey(for: isConfirmed)
    }

    /// Validates the confirmation checkbox, submits the record via the (stubbed) submission
    /// service, and routes on to the success screen once it succeeds.
    func submit() async {
        didAttemptSubmit = true
        submitFailed = false
        guard isConfirmed else { return }

        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await submissionService.submit(referenceNumber: referenceNumber)
            router.push(.submissionSuccess(referenceNumber: referenceNumber))
        } catch {
            submitFailed = true
        }
    }
}
