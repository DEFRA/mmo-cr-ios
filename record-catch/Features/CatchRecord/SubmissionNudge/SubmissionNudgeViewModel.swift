import Foundation

/// View model for the late-submission nudge screen.
///
/// Shown after a valid trip end (return) date when the trip ended more than 24 hours ago
/// (see `SubmissionNudge`). It is an information-only screen: "Save and continue" proceeds into
/// the port sub-journey (the same next step the return date screen would have taken), while the
/// "Check the trip end date" link pops back to correct the date. UI only — no persistence or
/// networking.
@MainActor
@Observable
final class SubmissionNudgeViewModel {

    /// Whole days the record is being submitted after the trip end date; drives the heading.
    let daysLate: Int
    /// Selected vessel name, threaded onward for the port screens' headers.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    private let router: CatchRecordRouter
    private let favouritePorts: FavouritePortsProviding

    init(
        daysLate: Int,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider()
    ) {
        self.daysLate = daysLate
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouritePorts = favouritePorts
    }

    /// "Save and continue" — acknowledges the nudge and continues into the port sub-journey.
    func submit() {
        Task { await enterPortSubJourney() }
    }

    /// "Check the trip end date" — pops back to the trip end date screen to correct it.
    func checkTripEndDate() {
        router.pop()
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
