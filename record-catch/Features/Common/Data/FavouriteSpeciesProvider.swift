import Foundation

/// The user's saved (favourite) species, along with any weights recorded against them.
///
/// API-shaped and per-user, mirroring `FavouriteGearProviding`/`FavouritePortsProviding` (see
/// ADR-0004). Offline-first: the local list is the source of truth for the "Record species weights"
/// and "Species summary" screens. Stubbed for now with an in-memory store; a future ADR covers the
/// real Favourites API and on-device persistence.
nonisolated protocol FavouriteSpeciesProviding: Sendable {
    /// The user's favourite species, ordered for display.
    func favouriteSpecies() async throws -> [SpeciesOption]
    /// Adds `species` to the user's favourites (replacing any existing entry with the same id, so
    /// re-recording a species updates its captured weights).
    func addFavourite(_ species: SpeciesOption) async throws
    /// Removes the species with the given id from the user's favourites.
    func removeFavourite(id: String) async throws
}

/// In-memory, UI-only favourite species store.
///
/// A `final class` (reference type) so a species added on the Add-species screen — and weights
/// recorded on the "Record species weights" screen — are visible to the summary screen the user
/// returns to within a journey. Not persisted to disk in this phase.
nonisolated final class StubFavouriteSpeciesProvider: FavouriteSpeciesProviding, @unchecked Sendable {

    private let lock = NSLock()
    private var favourites: [SpeciesOption]

    init(initialFavourites: [SpeciesOption] = []) {
        self.favourites = initialFavourites
    }

    func favouriteSpecies() async throws -> [SpeciesOption] {
        lock.withLock {
            favourites.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func addFavourite(_ species: SpeciesOption) async throws {
        lock.withLock {
            favourites.removeAll { $0.id == species.id }
            favourites.append(species)
        }
    }

    func removeFavourite(id: String) async throws {
        lock.withLock {
            favourites.removeAll { $0.id == id }
        }
    }
}
