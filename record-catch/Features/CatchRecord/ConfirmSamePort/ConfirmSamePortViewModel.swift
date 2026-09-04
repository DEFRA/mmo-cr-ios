import Foundation

/// View model for "Was `<port>` your departure and return port?".
///
/// Reached only from `AddPortView`'s **first-time entry** (no favourites yet — see
/// `AddPortViewModel.completionRoute`), once the searched port has been saved to favourites.
/// "Yes" sets both `CatchRecordDraft.departurePort` and `.returnPort` to the same port and enters
/// the gear sub-journey directly, skipping the separate departure/return select screens. "No"
/// continues into the departure select screen as before, so the user can pick (or add) different
/// ports for each leg. "Add another port" lets the user search again if the saved port was wrong.
@MainActor
@Observable
final class ConfirmSamePortViewModel {

    /// Selected vessel name, threaded onward to later screens' headers.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String
    /// The port just saved to favourites on `AddPortView`, named in the heading.
    let port: PortOption

    var selection: ConfirmSamePortOption?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    private let favouriteGears: FavouriteGearProviding
    /// Shared journey draft; "Yes" writes the same port into both fields (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        vessel: String,
        referenceNumber: String,
        port: PortOption,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.port = port
        self.router = router
        self.favouriteGears = favouriteGears
        self.draft = draft
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return ConfirmSamePortValidation.errorKey(for: selection)
    }

    /// Validates "Save and continue" and routes on for the current selection.
    func submit() {
        didAttemptSubmit = true
        guard let selection else { return }
        switch selection {
        case .yes:
            draft.departurePort = port
            draft.returnPort = port
            Task { await enterGearSubJourney() }
        case .no:
            router.push(.selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber))
        }
    }

    /// Fetches favourite gears, then pushes the pure gear-entry route (Add gear vs Select gear),
    /// mirroring `SelectPortViewModel.enterGearSubJourney`.
    func enterGearSubJourney() async {
        let favourites = (try? await favouriteGears.favouriteGears()) ?? []
        router.push(CatchRecordRouting.gearEntryRoute(
            hasFavourites: !favourites.isEmpty,
            vessel: vessel,
            referenceNumber: referenceNumber
        ))
    }

    /// Routes to the Add-port screen to search for a different port (first-time entry again).
    func addAnotherPort() {
        router.push(.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: nil))
    }
}
