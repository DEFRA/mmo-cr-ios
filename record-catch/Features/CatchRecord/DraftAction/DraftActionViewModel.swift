import Foundation

/// View model for the Draft action screen (what to do with an existing unsent record).
///
/// "Delete" requires a destructive confirmation before the router returns to Home
/// (`popToRoot()`), and also removes the persisted draft (see ADR-0014). "Complete" loads the
/// persisted draft's full payload into the shared `CatchRecordDraft` (so every screen the user
/// revisits is pre-filled with what was already captured — see ADR-0015 decision #1), then
/// restarts the journey from the very first screen (`.selectVessel`).
@MainActor
@Observable
final class DraftActionViewModel {

    /// The unsent record this screen is acting on.
    let row: SubmissionRow

    var selection: DraftActionOption?
    private(set) var didAttemptSubmit = false
    var showDeleteConfirmation = false

    private let router: CatchRecordRouter
    private let draft: CatchRecordDraft
    private let draftStore: CatchRecordDraftStoring

    init(
        row: SubmissionRow,
        router: CatchRecordRouter,
        draft: CatchRecordDraft = CatchRecordDraft(),
        draftStore: CatchRecordDraftStoring = InMemoryCatchRecordDraftStore()
    ) {
        self.row = row
        self.router = router
        self.draft = draft
        self.draftStore = draftStore
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return DraftActionValidation.errorKey(for: selection)
    }

    /// Runs validation for "Save and continue". Complete resumes the persisted draft; Delete opens
    /// a destructive confirmation dialog rather than routing directly.
    func submit() {
        didAttemptSubmit = true
        guard let selection else { return }

        switch selection {
        case .complete:
            Task { await resumeDraft() }
        case .delete:
            showDeleteConfirmation = true
        }
    }

    /// Loads the persisted draft's full payload (if any) into the shared, journey-scoped
    /// `CatchRecordDraft` — mutating it in place so every screen already holding a reference to it
    /// observes the resumed values — then restarts the journey from the first screen. A row with
    /// no known `localID`, or a draft that failed to load (e.g. already deleted), simply starts a
    /// blank journey rather than blocking the user.
    func resumeDraft() async {
        if let localID = row.localID, let payload = try? await draftStore.loadDraft(localID: localID) {
            draft.apply(payload)
        }
        router.push(.selectVessel)
    }

    /// Confirms the destructive delete: dismisses the dialog, returns to Home, and removes the
    /// persisted draft (fire-and-forget — the router transition is not gated on the delete
    /// completing, matching the offline-first "never block navigation on IO" pattern used
    /// elsewhere in this module).
    func confirmDelete() {
        showDeleteConfirmation = false
        router.popToRoot()
        guard let localID = row.localID else { return }
        Task { try? await draftStore.deleteDraft(localID: localID) }
    }

    /// Cancels the destructive delete: dismisses the dialog, selection unchanged.
    func cancelDelete() {
        showDeleteConfirmation = false
    }
}
