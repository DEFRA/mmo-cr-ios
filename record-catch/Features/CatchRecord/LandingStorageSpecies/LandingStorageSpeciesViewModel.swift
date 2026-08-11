import Foundation

/// View model for the "Which species from this trip are you not landing straight away?" screen.
///
/// Reached from the "Yes" answer on the landing-storage question. Loads the user's favourite
/// species (offline-first, local source of truth — mirrors `RecordSpeciesWeightsViewModel`), lets
/// the user tick species that are being kept onboard/in keep pots, and records a single weight for
/// each ticked species ("weight above minimum size kept onboard or in keep pots"). On
/// "Save and continue" the captured weights are written back to favourites and the journey routes
/// to the placeholder next step.
///
/// Weight validation is intentionally deferred to a future phase — the field accepts free input.
@MainActor
@Observable
final class LandingStorageSpeciesViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The user's favourite species, loaded from the provider.
    private(set) var favourites: [SpeciesOption] = []
    /// The ids of the ticked species.
    var selection: Set<String> = []
    /// Per-species raw weight entries, keyed by species id.
    var weightEntries: [String: String] = [:]

    private(set) var isSaving = false
    /// Set when saving to favourites fails, so the view can surface a recoverable error.
    private(set) var saveFailed = false

    private let router: CatchRecordRouter
    private let favouriteSpecies: FavouriteSpeciesProviding

    init(
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider()
    ) {
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteSpecies = favouriteSpecies
    }

    /// Loads favourite species and seeds any previously-captured weights into the field.
    func loadFavourites() async {
        let loaded = (try? await favouriteSpecies.favouriteSpecies()) ?? []
        favourites = loaded
        for species in loaded where !species.weightAboveMinimumKg.isEmpty {
            selection.insert(species.id)
            weightEntries[species.id] = species.weightAboveMinimumKg
        }
    }

    /// Whether a species is currently ticked.
    func isSelected(_ id: String) -> Bool { selection.contains(id) }

    /// Toggles a species' ticked state.
    func toggleSelection(_ id: String) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// The route to push after saving. Pure, so it is directly unit-testable.
    var completionRoute: CatchRecordRoute { .placeholderNextStep }

    /// Writes captured weights for ticked species back to favourites, then routes onward.
    ///
    /// Validation is deferred, so any ticked species (with or without an entered weight) is saved.
    func submit() async {
        saveFailed = false
        isSaving = true
        defer { isSaving = false }
        do {
            for species in favourites where selection.contains(species.id) {
                let captured = species.withWeights(
                    above: weightEntries[species.id] ?? "",
                    below: species.weightBelowMinimumKg,
                    discarded: species.weightLegallyDiscardedKg
                )
                try await favouriteSpecies.addFavourite(captured)
            }
            router.push(completionRoute)
        } catch {
            saveFailed = true
        }
    }
}
