import Foundation

/// The user's saved (favourite) gears.
///
/// API-shaped and per-user, mirroring `FavouritePortsProviding` (see ADR-0004). Offline-first: the
/// local list is the source of truth for the "What gear did you use?" screen. Stubbed for now with
/// an in-memory store; a future ADR covers the real Favourites API and on-device persistence.
nonisolated protocol FavouriteGearProviding: Sendable {
    /// The user's favourite gears, ordered for display.
    func favouriteGears() async throws -> [GearOption]
    /// Adds `gear` to the user's favourites (replacing any existing entry with the same id).
    func addFavourite(_ gear: GearOption) async throws
}

/// In-memory, UI-only favourite gears store.
///
/// A `final class` (reference type) so a gear added on the measurements screen is visible to the
/// select screen the user returns to within a journey. Not persisted to disk in this phase.
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
