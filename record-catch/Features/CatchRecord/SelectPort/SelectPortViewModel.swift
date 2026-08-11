import Foundation

/// View model for the reusable "select favourite port" screen (departure and return variants).
///
/// Loads the user's favourite ports (offline-first, local source of truth — see ADR-0004),
/// validates the selection, and routes on: departure → return, return → next step. "Add another
/// port" pushes the Add-port screen carrying this phase so it returns here afterwards.
@MainActor
@Observable
final class SelectPortViewModel {

    /// Which port this screen is collecting; drives copy, identifiers and the next route.
    let phase: SelectPortPhase
    /// Selected vessel name, threaded onward for the Add-port header.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The user's favourite ports, loaded from the provider.
    private(set) var favourites: [PortOption] = []
    var selection: String?
    private(set) var didAttemptSubmit = false

    private let router: CatchRecordRouter
    private let favouritePorts: FavouritePortsProviding
    private let favouriteGears: FavouriteGearProviding
    /// Shared journey draft; the selected port is written into it on submit (see `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        phase: SelectPortPhase,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding = StubFavouritePortsProvider(),
        favouriteGears: FavouriteGearProviding = StubFavouriteGearProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.phase = phase
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouritePorts = favouritePorts
        self.favouriteGears = favouriteGears
        self.draft = draft
    }

    /// Loads favourite ports for display. Failures leave the list empty.
    func loadFavourites() async {
        favourites = (try? await favouritePorts.favouritePorts()) ?? []
    }

    /// Current inline error, once a submit has been attempted.
    var errorKey: String? {
        guard didAttemptSubmit else { return nil }
        return SelectPortValidation.errorKey(for: selection, phase: phase)
    }

    /// Validates "Save and continue" and routes on when a port is selected.
    func submit() {
        didAttemptSubmit = true
        guard selection != nil else { return }
        let selectedPort = favourites.first { $0.name == selection }
        switch phase {
        case .departure:
            draft.departurePort = selectedPort
            router.push(.selectPort(phase: .return, vessel: vessel, referenceNumber: referenceNumber))
        case .return:
            draft.returnPort = selectedPort
            Task { await enterGearSubJourney() }
        }
    }

    /// Fetches favourite gears, then pushes the pure gear-entry route (Add gear vs Select gear).
    func enterGearSubJourney() async {
        let favourites = (try? await favouriteGears.favouriteGears()) ?? []
        router.push(CatchRecordRouting.gearEntryRoute(
            hasFavourites: !favourites.isEmpty,
            vessel: vessel,
            referenceNumber: referenceNumber
        ))
    }

    /// Routes to the Add-port screen, recording this phase so it returns here after saving.
    func addAnotherPort() {
        router.push(.addPort(vessel: vessel, referenceNumber: referenceNumber, returnPhase: phase))
    }
}
