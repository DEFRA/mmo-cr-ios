import Foundation

/// View model for the "Is there any catch you will not be landing straight away?" screen.
///
/// A Yes/No radio question reached after the species summary. "Yes" continues to the
/// "Which species are you not landing straight away?" screen; "No" continues to the placeholder
/// next step. The answer is not yet persisted.
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
        router.push(completionRoute)
    }
}
