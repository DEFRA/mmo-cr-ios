import Foundation

/// View model for the Add-species screen (type-to-search, save to favourites).
///
/// UI-shaped but backed by stubbed, API-shaped providers (see ADR-0004). On a valid selection it
/// adds the species to the user's favourites, then routes back to the screen recorded in
/// `returnPhase`. Selection validation is intentionally deferred — a submit with no selection simply
/// does nothing for now.
@MainActor
@Observable
final class AddSpeciesViewModel {

    /// The gear these species were caught with, threaded onward.
    let gear: GearOption
    /// Selected vessel name, shown in the header ("Add species to vessel <VESSEL>").
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String
    /// Which screen to return to after saving.
    let returnPhase: SpeciesReturnPhase

    /// The current search text.
    var query: String = ""
    /// The species name selected from the results list (nil until one is chosen).
    var selectedName: String?
    private(set) var isSaving = false
    /// Set when saving to favourites fails, so the view can surface a recoverable error.
    private(set) var saveFailed = false

    /// Species names available to the search field (loaded from the species provider).
    private(set) var speciesNames: [String] = []

    private let router: CatchRecordRouter
    private let speciesSearch: SpeciesSearchProviding
    private let favouriteSpecies: FavouriteSpeciesProviding

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        returnPhase: SpeciesReturnPhase,
        router: CatchRecordRouter,
        speciesSearch: SpeciesSearchProviding = StubSpeciesSearchProvider(),
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider()
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.returnPhase = returnPhase
        self.router = router
        self.speciesSearch = speciesSearch
        self.favouriteSpecies = favouriteSpecies
    }

    /// The selected `SpeciesOption`, if the user has chosen one from the list.
    var selectedSpecies: SpeciesOption? {
        selectedName.map(SpeciesOption.init(name:))
    }

    /// The route to push after a successful save. Pure and independent of async work, so it is
    /// directly unit-testable.
    var completionRoute: CatchRecordRoute {
        switch returnPhase {
        case .recordWeights:
            return .recordSpeciesWeights(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
        case .summary:
            // The Species Summary screen has been removed from the journey; the (now unused)
            // `.summary` return phase falls back to the record-weights screen.
            return .recordSpeciesWeights(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
        }
    }

    /// Loads the searchable species list up front so the field can filter locally. Failures leave
    /// the list empty (the search simply returns no results) rather than blocking the screen.
    func loadSpecies() async {
        speciesNames = ((try? await speciesSearch.allSpecies()) ?? []).map(\.name)
    }

    /// Adds the selected species to favourites, then routes back to the recorded screen. Does
    /// nothing when no species is selected (validation deferred).
    func submit() async {
        saveFailed = false
        guard let species = selectedSpecies else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await favouriteSpecies.addFavourite(species)
            router.push(completionRoute)
        } catch {
            saveFailed = true
        }
    }
}
