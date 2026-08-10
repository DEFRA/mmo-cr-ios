import Foundation

/// View model for the "Did your trip start and finish today?" screen.
@MainActor
@Observable
final class TripStartedTodayViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    var selection: TripTodayOption?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter

    init(referenceNumber: String, router: CatchRecordRouter) {
        self.referenceNumber = referenceNumber
        self.router = router
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return TripTodayValidation.errorKey(for: selection)
    }

    /// Runs validation for "Save and continue" and routes on to the next screen when valid.
    ///
    /// "Yes" (trip started and finished today) continues to the next step; "No" branches into
    /// the trip-date sub-journey, starting with the departure date.
    func submit() {
        didAttemptSubmit = true
        guard let selection else { return }
        switch selection {
        case .yes:
            router.push(.placeholderNextStep)
        case .no:
            router.push(.tripDate(phase: .departure, referenceNumber: referenceNumber, departureDate: nil))
        }
    }
}
