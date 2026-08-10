import Foundation

/// The user's saved (favourite) ports.
///
/// API-shaped and **per-user** (not per-vessel) — see ADR-0004. Offline-first: the local list is
/// the source of truth for the "Which port did you leave from/return to?" screens. Stubbed for now
/// with an in-memory store; a future ADR covers the real Favourites API and on-device persistence.
nonisolated protocol FavouritePortsProviding: Sendable {
    /// The user's favourite ports, ordered for display.
    func favouritePorts() async throws -> [PortOption]
    /// Adds `port` to the user's favourites (no-op if already present).
    func addFavourite(_ port: PortOption) async throws
}

/// In-memory, UI-only favourites store.
///
/// A `final class` (reference type) so a favourite added on the Add-port screen is visible to the
/// select screen the user returns to within a journey. Not persisted to disk in this phase.
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
