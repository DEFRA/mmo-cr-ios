import Foundation

/// View model for the "Which species did you catch with <gear>?" screen.
///
/// Loads the user's favourite species (offline-first, local source of truth — mirrors gears), lets
/// the user tick species and enter live weights (the "above minimum" field is always shown when a
/// species is ticked; "below minimum" and "legally discarded" are optional fields the user can
/// reveal and remove). On "Save and continue" the captured weights are written back to favourites
/// and the journey routes to the summary. "Add a species" pushes the Add-species search screen.
///
/// Weight validation is intentionally deferred to a future phase — fields accept free input for now.
@MainActor
@Observable
final class RecordSpeciesWeightsViewModel {

    /// The gear these species were caught with — supplies the "with <gear>" part of the heading.
    let gear: GearOption
    /// Selected vessel name, threaded onward for the Add-species header.
    let vessel: String
    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    /// The user's favourite species, loaded from the provider.
    private(set) var favourites: [SpeciesOption] = []
    /// The ids of the ticked species.
    var selection: Set<String> = []

    /// Per-species raw weight entries, keyed by species id.
    var aboveEntries: [String: String] = [:]
    var belowEntries: [String: String] = [:]
    var discardedEntries: [String: String] = [:]
    /// Species ids for which the optional "below minimum" / "legally discarded" fields are revealed.
    private(set) var belowRevealed: Set<String> = []
    private(set) var discardedRevealed: Set<String> = []

    private(set) var isSaving = false
    /// Set when saving to favourites fails, so the view can surface a recoverable error.
    private(set) var saveFailed = false

    private let router: CatchRecordRouter
    private let favouriteSpecies: FavouriteSpeciesProviding

    init(
        gear: GearOption,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouriteSpecies: FavouriteSpeciesProviding = StubFavouriteSpeciesProvider()
    ) {
        self.gear = gear
        self.vessel = vessel
        self.referenceNumber = referenceNumber
        self.router = router
        self.favouriteSpecies = favouriteSpecies
    }

    /// Loads favourite species and seeds any previously-captured weights into the fields (so
    /// returning to this screen shows what was already recorded). Failures leave the list empty.
    func loadFavourites() async {
        let loaded = (try? await favouriteSpecies.favouriteSpecies()) ?? []
        favourites = loaded
        for species in loaded {
            if !species.weightAboveMinimumKg.isEmpty
                || species.weightBelowMinimumKg != nil
                || species.weightLegallyDiscardedKg != nil {
                selection.insert(species.id)
            }
            aboveEntries[species.id] = species.weightAboveMinimumKg
            if let below = species.weightBelowMinimumKg {
                belowEntries[species.id] = below
                belowRevealed.insert(species.id)
            }
            if let discarded = species.weightLegallyDiscardedKg {
                discardedEntries[species.id] = discarded
                discardedRevealed.insert(species.id)
            }
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

    /// Whether the optional "below minimum" field is revealed for a species.
    func isBelowRevealed(_ id: String) -> Bool { belowRevealed.contains(id) }
    /// Whether the optional "legally discarded" field is revealed for a species.
    func isDiscardedRevealed(_ id: String) -> Bool { discardedRevealed.contains(id) }

    func revealBelow(_ id: String) { belowRevealed.insert(id) }
    func removeBelow(_ id: String) {
        belowRevealed.remove(id)
        belowEntries[id] = nil
    }

    func revealDiscarded(_ id: String) { discardedRevealed.insert(id) }
    func removeDiscarded(_ id: String) {
        discardedRevealed.remove(id)
        discardedEntries[id] = nil
    }

    /// The route to push after saving. Pure and independent of async work, so it is directly
    /// unit-testable.
    var completionRoute: CatchRecordRoute {
        .speciesSummary(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
    }

    /// Routes to the Add-species search screen, returning here afterwards.
    func addSpecies() {
        router.push(.addSpecies(
            gear: gear,
            vessel: vessel,
            referenceNumber: referenceNumber,
            returnPhase: .recordWeights
        ))
    }

    /// Builds a species with its captured weights from the current field state.
    private func capturedSpecies(_ species: SpeciesOption) -> SpeciesOption {
        species.withWeights(
            above: aboveEntries[species.id] ?? "",
            below: belowRevealed.contains(species.id) ? (belowEntries[species.id] ?? "") : nil,
            discarded: discardedRevealed.contains(species.id) ? (discardedEntries[species.id] ?? "") : nil
        )
    }

    /// Writes captured weights for ticked species back to favourites, then routes to the summary.
    ///
    /// Validation is deferred, so any ticked species (with or without entered weights) is saved.
    func submit() async {
        saveFailed = false
        isSaving = true
        defer { isSaving = false }
        do {
            for species in favourites where selection.contains(species.id) {
                try await favouriteSpecies.addFavourite(capturedSpecies(species))
            }
            router.push(completionRoute)
        } catch {
            saveFailed = true
        }
    }
}
