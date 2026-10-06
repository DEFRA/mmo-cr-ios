import Foundation

/// View model for the "Your catch record has been saved" screen.
///
/// Reached instead of `SubmissionSuccessViewModel`'s screen when
/// `SubmissionConfirmationViewModel.submit()` detects the device has no connectivity
/// (BR-SUB-008/AC10/AC11): the record stays saved on-device and was never submitted. Holds no
/// other state — this screen is a read-only explanation — so its only intent is "View your catch
/// records", which returns to Home (the record remains visible there as an Unsent row).
@MainActor
@Observable
final class SubmissionSavedViewModel {

    /// The reference number of the saved-but-not-submitted catch record.
    let referenceNumber: String

    private let router: CatchRecordRouter

    init(referenceNumber: String, router: CatchRecordRouter) {
        self.referenceNumber = referenceNumber
        self.router = router
    }

    /// Returns to Home, clearing the whole journey stack. The record is not lost — it remains on
    /// Home as an Unsent row, resumable from the same point (see `CatchRecordDraftStoring`).
    func viewCatchRecords() {
        router.popToRoot()
    }
}
