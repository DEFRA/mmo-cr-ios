import Foundation

/// View model for the "Species caught with <gear> on vessel <VESSEL>" summary screen.
///
/// Lists the species recorded so far (the user's favourites that have weights captured) with their
/// weights, lets the user remove any, add another, or continue. Offline-first: the favourites store
/// is the local source of truth (mirrors gears/ports). Routes to `.landingStorage` on continue.
@MainActor
@Observable
final class SpeciesSummaryViewModel {

    /// The gear these species were caught with — supplies the "with <gear>" part of the heading.
    let gear: GearOption
    /// Selected vessel name, shown in the header and threaded onward.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The recorded species, loaded from the favourites provider.
    private(set) var species: [SpeciesOption] = []

    private let router: CatchRecordRouter
    private let favouriteSpecies: FavouriteSpeciesProviding
    /// Shared journey draft; the recorded species-caught list is written into it on submit (see
    /// `CatchRecordDraft`).
    private let draft: CatchRecordDraft

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteSpecies = favouriteSpecies
        self.draft = draft
    }

    /// Loads the recorded species for display. Failures leave the list empty.
    func loadSpecies() async {
        species = (try? await favouriteSpecies.favouriteSpecies()) ?? []
    }

    /// Removes a recorded species and refreshes the list.
    func remove(id: String) async {
        try? await favouriteSpecies.removeFavourite(id: id)
        await loadSpecies()
    }

    /// Routes to the Add-species search screen, returning to this summary afterwards.
    func addAnother() {
        router.push(.addSpecies(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            returnPhase: .summary
        ))
    }

    /// Continues to the next step in the journey.
    func submit() {
        draft.speciesCaught = species
        router.push(.landingStorage(referenceNumber: referenceNumber))
    }
}
