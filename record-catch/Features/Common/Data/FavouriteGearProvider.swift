import Foundation

/// The user's saved (favourite) gears.
///
/// API-shaped and **per-user, not per-trip** (see ADR-0004, amended by ADR-0023): a gear added to
/// favourites belongs to the signed-in user and persists across every future trip, not just the
/// journey that added it. Offline-first: the on-device `SwiftDataFavouriteGearProvider` is the
/// source of truth for the "What gear did you use?" screen (see `FavouriteEntity`).
nonisolated protocol FavouriteGearProviding: Sendable {
    /// The user's favourite gears, ordered for display.
    func favouriteGears() async throws -> [GearOption]
    /// Adds `gear` to the user's favourites (replacing any existing entry with the same id).
    func addFavourite(_ gear: GearOption) async throws
}

/// In-memory, UI-only favourite gears store — used by previews and unit/UI tests that don't need
/// real persistence. Production uses `SwiftDataFavouriteGearProvider` instead (see ADR-0023).
///
/// A `final class` (reference type) so a gear added on the measurements screen is visible to the
/// select screen the user returns to within a journey.
nonisolated final class StubFavouriteGearProvider: FavouriteGearProviding, @unchecked Sendable {

    private let lock = NSLock()
    private var favourites: [GearOption]

    init(initialFavourites: [GearOption] = []) {
        self.favourites = initialFavourites
    }

    func favouriteGears() async throws -> [GearOption] {
        lock.withLock {
            favourites.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func addFavourite(_ gear: GearOption) async throws {
        lock.withLock {
            favourites.removeAll { $0.id == gear.id }
            favourites.append(gear)
        }
    }
}
