import Foundation

/// View model for the "Is there any catch you will not be landing straight away?" screen.
///
/// A Yes/No radio question reached after the species weights screen. "Yes" continues to the
/// "Which species are you not landing straight away?" screen; "No" continues to Check your
/// answers.
@MainActor
@Observable
final class LandingStorageViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    var selection: LandingStorageOption?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    /// Shared journey draft; advanced to `.landingStorage` once this question is answered (see
    /// `CatchRecordDraft.checkpoint`).
    private let draft: CatchRecordDraft

    init(referenceNumber: String, router: CatchRecordRouter, draft: CatchRecordDraft = CatchRecordDraft()) {
        self.referenceNumber = referenceNumber
        self.router = router
        self.draft = draft
        // Pre-fills "Yes" when restarting a resumed draft that already recorded species not
        // landed (see ADR-0015 decision #1). There is no persisted "No" answer to infer from an
        // empty list, so it is left unselected rather than guessed.
        if !draft.speciesNotLanded.isEmpty {
            self.selection = .yes
        }
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return LandingStorageValidation.errorKey(for: selection)
    }

    /// The route to push for the current selection. Pure, so it is directly unit-testable.
    /// "Yes" leads to the not-landing species screen; "No" ends the journey at Check your answers.
    var completionRoute: CatchRecordRoute {
        switch selection {
        case .yes:
            return .landingStorageSpecies(referenceNumber: referenceNumber)
        case .no, .none:
            return .checkYourAnswers(referenceNumber: referenceNumber)
        }
    }

    /// Runs validation for "Save and continue" and routes on to the next screen when valid.
    func submit() {
        didAttemptSubmit = true
        guard selection != nil else { return }
        draft.advance(to: .landingStorage)
        router.push(completionRoute)
    }
}
