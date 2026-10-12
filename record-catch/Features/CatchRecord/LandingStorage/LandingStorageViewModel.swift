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
    /// `CatchRecordDraft.checkpoint`). Also supplies `vessel`/`returnDate` for the "Check your
    /// catch record" vs. late-submission-nudge routing decision (see `completionRoute`).
    private let draft: CatchRecordDraft
    /// Injected so the late-submission check (`completionRoute`) is deterministic in tests rather
    /// than depending on the wall clock — mirrors `TripDateViewModel`.
    private let now: () -> Date

    init(
        referenceNumber: String,
        router: CatchRecordRouter,
        draft: CatchRecordDraft = CatchRecordDraft(),
        now: @escaping () -> Date = Date.init
    ) {
        self.referenceNumber = referenceNumber
        self.router = router
        self.draft = draft
        self.now = now
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

    /// The route to push for the current selection. Pure (given the current draft/clock state),
    /// so it is directly unit-testable. "Yes" leads to the not-landing species screen; "No" ends
    /// the journey at "Check your catch record" — or the late-submission nudge first, when the
    /// trip ended more than 24 hours ago (see `CatchRecordRouting.checkYourAnswersOrNudgeRoute`).
    var completionRoute: CatchRecordRoute {
        switch selection {
        case .yes:
            return .landingStorageSpecies(referenceNumber: referenceNumber)
        case .no, .none:
            return CatchRecordRouting.checkYourAnswersOrNudgeRoute(
                tripEndDate: draft.returnDate,
                vessel: draft.vessel ?? "",
                referenceNumber: referenceNumber,
                now: now()
            )
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
