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
    /// Selected vessel name, threaded onward for the port screens' headers.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String
    /// The parsed departure date carried into the return screen (nil for the departure screen).
    let departureDate: Date?

    var value = DateEntryValue()
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    private let favouritePorts: FavouritePortsProviding

    init(
        phase: TripDatePhase,
        vessel: String,
        referenceNumber: String,
        departureDate: Date?,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider()
    ) {
        self.phase = phase
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.departureDate = departureDate
        self.router = router
        self.favouritePorts = favouritePorts
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
            router.push(.tripDate(phase: .return, vessel: vessel, referenceNumber: referenceNumber, departureDate: date))
        case .return:
            Task { await enterPortSubJourney() }
        }
    }

    /// Fetches favourites, then pushes the pure port-entry route (Add port vs Select departure).
    func enterPortSubJourney() async {
        let favourites = (try? await favouritePorts.favouritePorts()) ?? []
        router.push(CatchRecordRouting.portEntryRoute(
            hasFavourites: !favourites.isEmpty,
            vessel: vessel,
            referenceNumber: referenceNumber
        ))
    }
}
