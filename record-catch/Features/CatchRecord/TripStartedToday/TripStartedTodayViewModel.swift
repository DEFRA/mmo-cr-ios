import Foundation

/// View model for the "Did your trip start and finish today?" screen.
@MainActor
@Observable
final class TripStartedTodayViewModel {

    /// Selected vessel name, threaded onward for the port screens' headers.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    var selection: TripTodayOption?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    private let favouritePorts: FavouritePortsProviding

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider()
    ) {
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouritePorts = favouritePorts
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return TripTodayValidation.errorKey(for: selection)
    }

    /// Runs validation for "Save and continue" and routes on to the next screen when valid.
    ///
    /// "Yes" (trip started and finished today) enters the port sub-journey now; "No" branches into
    /// the trip-date sub-journey, starting with the departure date.
    func submit() {
        didAttemptSubmit = true
        guard let selection else { return }
        switch selection {
        case .yes:
            Task { await enterPortSubJourney() }
        case .no:
            router.push(.tripDate(phase: .departure, vessel: vessel, referenceNumber: referenceNumber, departureDate: nil))
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
