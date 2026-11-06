import Foundation

/// The user's saved (favourite) species.
///
/// API-shaped and **per-user, not per-trip** (see ADR-0004, amended by ADR-0023): a species added
/// to favourites belongs to the signed-in user and persists across every future trip. Offline-first:
/// the on-device `SwiftDataFavouriteSpeciesProvider` is the source of truth for the "Record species
/// weights" screen (see `FavouriteEntity`).
///
/// **Does not carry per-trip weights.** Earlier revisions of this type stored each favourite's
/// last-recorded weights; a weight is per-trip data and must not silently carry over to the next
/// trip, so weights now live only on `CatchRecordDraft.gearCatches[…].speciesCaught` (see
/// `RecordSpeciesWeightsViewModel.submit()`, ADR-0023).
nonisolated protocol FavouriteSpeciesProviding: Sendable {
    /// The user's favourite species, ordered for display.
    func favouriteSpecies() async throws -> [SpeciesOption]
    /// Adds `species` to the user's favourites (replacing any existing entry with the same id).
    /// Callers must strip any per-trip weights from `species` first — see the type's doc comment.
    func addFavourite(_ species: SpeciesOption) async throws
    /// Removes the species with the given id from the user's favourites.
    func removeFavourite(id: String) async throws
}

/// In-memory, UI-only favourite species store — used by previews and unit/UI tests that don't need
/// real persistence. Production uses `SwiftDataFavouriteSpeciesProvider` instead (see ADR-0023).
///
/// A `final class` (reference type) so a species added on the Add-species screen is visible to the
/// screen the user returns to within a journey.
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
