import Foundation

/// View model for the Select vessel screen.
///
/// UI only — vessels come from an injected `VesselProviding` so a future API-backed provider can
/// swap in without changing this view model or its tests.
@MainActor
@Observable
final class SelectVesselViewModel {

    /// Static, UI-only placeholder reference number shown on the next screen. Not derived from
    /// any backend — see the design spec's "Reference number placeholder note".
    static let placeholderReferenceNumber = "A1234520260727150815"

    let vessels: [String]
    var selection: String?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    /// Shared journey draft; the chosen vessel is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        router: CatchRecordRouter,
        provider: VesselProviding = StaticVesselProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.router = router
        self.vessels = provider.vessels
        self.draft = draft
        // Pre-fills the previously-captured vessel when restarting a resumed draft from the
        // beginning (see ADR-0015 decision #1), so the user is not asked to re-choose it.
        self.selection = draft.vessel
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SelectVesselValidation.errorKey(for: selection)
    }

    /// Runs validation for "Save and continue" and, once valid, replaces this screen with the
    /// journey's next one.
    ///
    /// Vessel selection is a one-time, first step of the journey (see ADR-0013 amendment — the
    /// vessel cannot be changed once a record exists): there is no "Change" link to it from Check
    /// your answers, and `router.replaceCurrent(with:)` removes `.selectVessel` from the
    /// navigation stack as it commits, rather than pushing on top of it — so Back/the swipe-back
    /// gesture from the next screen leaves the journey (returning to Home) instead of re-opening
    /// vessel selection.
    func submit() {
        didAttemptSubmit = true
        guard let selection else { return }
        draft.vessel = selection
        router.replaceCurrent(with: .tripStartedToday(vessel: selection, referenceNumber: Self.placeholderReferenceNumber))
    }
}
