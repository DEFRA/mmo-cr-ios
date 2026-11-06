import Foundation

/// The user's saved (favourite) ports.
///
/// API-shaped and **per-user, not per-vessel or per-trip** (see ADR-0004, amended by ADR-0023): a
/// port added to favourites belongs to the signed-in user and persists across every future trip.
/// Offline-first: the on-device `SwiftDataFavouritePortsProvider` is the source of truth for the
/// "Which port did you leave from/return to?" screens (see `FavouriteEntity`).
nonisolated protocol FavouritePortsProviding: Sendable {
    /// The user's favourite ports, ordered for display.
    func favouritePorts() async throws -> [PortOption]
    /// Adds `port` to the user's favourites (no-op if already present).
    func addFavourite(_ port: PortOption) async throws
}

/// In-memory, UI-only favourites store — used by previews and unit/UI tests that don't need real
/// persistence. Production uses `SwiftDataFavouritePortsProvider` instead (see ADR-0023).
///
/// A `final class` (reference type) so a favourite added on the Add-port screen is visible to the
/// select screen the user returns to within a journey.
nonisolated final class StubFavouritePortsProvider: FavouritePortsProviding, @unchecked Sendable {

    private let lock = NSLock()
    private var favourites: [PortOption]

    init(initialFavourites: [PortOption] = []) {
        self.favourites = initialFavourites
    }

    func favouritePorts() async throws -> [PortOption] {
        lock.withLock {
            favourites.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func addFavourite(_ port: PortOption) async throws {
        lock.withLock {
            guard !favourites.contains(port) else { return }
            favourites.append(port)
        }
    }
}
