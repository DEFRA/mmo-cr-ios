import Foundation

/// View model for the "Confirmation" screen — the final gate before submitting a completed catch
/// record, reached from "Save and continue" on Check your answers.
///
/// Requires the user to tick a single confirmation checkbox acknowledging the record is complete
/// and accurate before "Accept and submit trip details" proceeds; declining to tick it shows an
/// inline error and does not navigate. Actual submission to a backend is not yet implemented in
/// this UI-only phase — a confirmed submit continues to the placeholder next step.
@MainActor
@Observable
final class SubmissionConfirmationViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    var isConfirmed = false
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter

    init(referenceNumber: String, router: CatchRecordRouter) {
        self.referenceNumber = referenceNumber
        self.router = router
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SubmissionConfirmationValidation.errorKey(for: isConfirmed)
    }

    /// Validates the confirmation checkbox and routes on to the next step once ticked.
    func submit() {
        didAttemptSubmit = true
        guard isConfirmed else { return }
        router.push(.placeholderNextStep)
    }
}
