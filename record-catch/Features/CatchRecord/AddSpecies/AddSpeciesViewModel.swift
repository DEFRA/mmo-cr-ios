import Foundation

/// The screen-navigation parameters for `AddSpeciesViewModel`, grouped into one value so the view
/// model's initialiser stays within the project's parameter-count limit (max 7).
///
/// Mirrors the parameters `AddSpeciesView`/`CatchRecordRoute.addSpecies` already thread through as
/// a group; grouping them here does not change any call site's *values*, only how they are passed.
struct AddSpeciesRequest {
    /// The gear these species were caught with, threaded onward.
    let gear: GearOption
    /// Selected vessel name, shown in the header ("Add species to vessel <VESSEL>").
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String
    /// Which screen to return to after saving.
    let returnPhase: SpeciesReturnPhase
    /// Which entry point this screen was reached from — drives validation copy.
    let context: AddSpeciesContext

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        returnPhase: SpeciesReturnPhase,
        context: AddSpeciesContext
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.returnPhase = returnPhase
        self.context = context
    }
}

/// View model for the Add-species screen (type-to-search, save to favourites).
///
/// UI-shaped but backed by stubbed, API-shaped providers (see ADR-0004). On a valid selection it
/// adds the species to the user's favourites, then routes back to the screen recorded in
/// `returnPhase`. Validated on "Save and continue" (see `AddSpeciesValidation`): the search field
/// must not be blank, and once typed a species must be picked from the results list. Copy is
/// context-specific (`AddSpeciesContext`, plan Q3): first-time entry vs "Add a species" while
/// already recording this trip's catch.
@MainActor
@Observable
final class AddSpeciesViewModel {

    /// The gear these species were caught with, threaded onward.
    var gear: GearOption { request.gear }
    /// Selected vessel name, shown in the header ("Add species to vessel <VESSEL>").
    var vessel: String { request.vessel }
    /// Display-only placeholder reference number shown at the top of the screen.
    var referenceNumber: String { request.referenceNumber }
    /// Which screen to return to after saving.
    var returnPhase: SpeciesReturnPhase { request.returnPhase }
    /// Which entry point this screen was reached from — drives validation copy.
    var context: AddSpeciesContext { request.context }

    /// The current search text.
    var query: String = ""
    /// The species name selected from the results list (nil until one is chosen).
    var selectedName: String?
    private(set) var didAttemptSubmit = false
    private(set) var isSaving = false
    /// Set when saving to favourites fails, so the view can surface a recoverable error.
    private(set) var saveFailed = false

    /// Species names available to the search field (loaded from the species provider).
    private(set) var speciesNames: [String] = []

    private let request: AddSpeciesRequest
    private let router: CatchRecordRouter
    private let speciesSearch: SpeciesSearchProviding
    private let favouriteSpecies: FavouriteSpeciesProviding

    init(
        request: AddSpeciesRequest,
        router: CatchRecordRouter,
        speciesSearch: SpeciesSearchProviding = StubSpeciesSearchProvider(),
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider()
    ) {
        self.request = request
        self.router = router
        self.speciesSearch = speciesSearch
        self.favouriteSpecies = favouriteSpecies
    }

    /// The selected `SpeciesOption`, if the user has chosen one from the list.
    var selectedSpecies: SpeciesOption? {
        selectedName.map(SpeciesOption.init(name:))
    }

    /// Current validation message, once a submit has been attempted.
    var validationMessage: ValidationMessage? {
        guard didAttemptSubmit else { return nil }
        return AddSpeciesValidation.message(query: query, selectedSpecies: selectedSpecies, context: context)
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

    /// Validates the selection, then adds it to favourites and routes back to the recorded screen.
    func submit() async {
        didAttemptSubmit = true
        saveFailed = false
        guard let species = selectedSpecies,
              AddSpeciesValidation.message(query: query, selectedSpecies: species, context: context) == nil else {
            return
        }
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
