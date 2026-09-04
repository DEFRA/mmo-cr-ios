import Foundation

/// Shared "enter the species sub-journey" routing decision, used by both `CatchLocationViewModel`
/// (map selection) and `CatchLocationManualEntryViewModel` (manual search entry) once a
/// statistical area has been chosen — the two are otherwise near-identical screens with a single
/// differing selection mechanism.
///
/// Fetches favourite species, then pushes the pure species-entry route (Record weights vs Add
/// species). Mirrors `SelectPortViewModel.enterGearSubJourney()`.
@MainActor
enum SpeciesSubJourneyEntry {
    static func enter(
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding,
        gear: GearOption,
        vessel: String,
        referenceNumber: String
    ) async {
        let favourites = (try? await favouriteSpecies.favouriteSpecies()) ?? []
        router.push(CatchRecordRouting.speciesEntryRoute(
            hasFavourites: !favourites.isEmpty,
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber
        ))
    }
}
