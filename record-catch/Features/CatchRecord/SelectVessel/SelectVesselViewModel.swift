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

    init(router: CatchRecordRouter, provider: VesselProviding = StaticVesselProvider()) {
        self.router = router
        self.vessels = provider.vessels
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SelectVesselValidation.errorKey(for: selection)
    }

    /// Runs validation for "Save and continue" and routes on to the next screen when valid.
    func submit() {
        didAttemptSubmit = true
        guard selection != nil else { return }
        router.push(.tripStartedToday(referenceNumber: Self.placeholderReferenceNumber))
    }
}
