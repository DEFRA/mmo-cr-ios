import Foundation

/// View model for the reusable trip-date screen (departure and return variants).
///
/// UI only — no persistence or networking. On a valid departure date it pushes the return
/// variant carrying the parsed departure date; on a valid return date it continues to the next
/// step. See ADR-0003 for the routing pattern.
@MainActor
@Observable
final class TripDateViewModel {

    /// Which date this screen is collecting; drives copy, identifiers and the next route.
    let phase: TripDatePhase
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String
    /// The parsed departure date carried into the return screen (nil for the departure screen).
    let departureDate: Date?

    var value = DateEntryValue()
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter

    init(
        phase: TripDatePhase,
        referenceNumber: String,
        departureDate: Date?,
        router: CatchRecordRouter
    ) {
        self.phase = phase
        self.referenceNumber = referenceNumber
        self.departureDate = departureDate
        self.router = router
    }

    /// String Catalog key for the screen's H1.
    var titleKey: String { phase.titleKey }

    /// String Catalog key for the screen's hint.
    var hintKey: String { phase.hintKey }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return TripDateValidation.errorKey(for: value)
    }

    /// Runs validation for "Save and continue" and routes on when the date is valid.
    func submit() {
        didAttemptSubmit = true
        guard let date = DateEntryField.parsedDate(from: value) else { return }
        switch phase {
        case .departure:
            router.push(.tripDate(phase: .return, referenceNumber: referenceNumber, departureDate: date))
        case .return:
            router.push(.placeholderNextStep)
        }
    }
}
