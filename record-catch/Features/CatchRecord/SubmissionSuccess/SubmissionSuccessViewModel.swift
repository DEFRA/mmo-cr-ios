import Foundation

/// View model for the final "Your catch record has been submitted" screen.
///
/// Reached once the (stubbed) submission API call on the Confirmation screen succeeds (see
/// `SubmissionConfirmationViewModel`). Holds no other state — this screen is a read-only summary —
/// so its only intent is "View your catch records", which returns to Home.
@MainActor
@Observable
final class SubmissionSuccessViewModel {

    /// The reference number of the just-submitted catch record, shown in the confirmation panel.
    let referenceNumber: String

    private let router: CatchRecordRouter

    init(referenceNumber: String, router: CatchRecordRouter) {
        self.referenceNumber = referenceNumber
        self.router = router
    }

    /// Returns to Home, clearing the whole journey stack — there is nothing to go "back" to once
    /// a record has been submitted.
    func viewCatchRecords() {
        router.popToRoot()
    }
}
