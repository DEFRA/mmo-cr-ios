import Foundation

/// View model for the "Is there any catch you will not be landing straight away?" screen.
///
/// A Yes/No radio question reached after the species summary. UI-only for this phase: both answers
/// continue to the placeholder next step (the answer is not yet persisted or branched on).
@MainActor
@Observable
final class LandingStorageViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    var selection: LandingStorageOption?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter

    init(referenceNumber: String, router: CatchRecordRouter) {
        self.referenceNumber = referenceNumber
        self.router = router
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return LandingStorageValidation.errorKey(for: selection)
    }

    /// Runs validation for "Save and continue" and routes on to the next screen when valid.
    func submit() {
        didAttemptSubmit = true
        guard selection != nil else { return }
        router.push(.placeholderNextStep)
    }
}
