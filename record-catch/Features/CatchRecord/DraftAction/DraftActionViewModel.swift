import Foundation

/// View model for the Draft action screen (what to do with an existing unsent record).
///
/// UI only — no persistence or networking. "Delete" requires a destructive confirmation before
/// the router returns to Home (`popToRoot()`); "Complete" pushes straight on to Select vessel.
@MainActor
@Observable
final class DraftActionViewModel {

    /// The unsent record this screen is acting on.
    let row: SubmissionRow

    var selection: DraftActionOption?
    private(set) var didAttemptSubmit = false
    var showDeleteConfirmation = false

    private let router: CatchRecordRouter

    init(row: SubmissionRow, router: CatchRecordRouter) {
        self.row = row
        self.router = router
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return DraftActionValidation.errorKey(for: selection)
    }

    /// Runs validation for "Save and continue". Complete routes on immediately; Delete opens a
    /// destructive confirmation dialog rather than routing directly.
    func submit() {
        didAttemptSubmit = true
        guard let selection else { return }

        switch selection {
        case .complete:
            router.push(.selectVessel)
        case .delete:
            showDeleteConfirmation = true
        }
    }

    /// Confirms the destructive delete: dismisses the dialog and returns to Home.
    func confirmDelete() {
        showDeleteConfirmation = false
        router.popToRoot()
    }

    /// Cancels the destructive delete: dismisses the dialog, selection unchanged.
    func cancelDelete() {
        showDeleteConfirmation = false
    }
}
