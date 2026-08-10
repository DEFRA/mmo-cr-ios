import Foundation

/// Supplies the gears a user can search for on the Add-gear screen.
///
/// API-shaped: `async throws` so a future real Gear API can swap in without changing the view model
/// or its tests (see ADR-0004). Stubbed for now — only Seine nets is available in this phase.
nonisolated protocol GearSearchProviding: Sendable {
    /// The full set of searchable gears, used to seed a locally-filtering search field.
    func allGears() async throws -> [GearOption]
}

/// Static, UI-only gear search. Stands in until a real Gear API exists.
///
/// Only Seine nets is provided for now (see the request to implement the seine-nets example only);
/// additional gears with their own measurements can be added here without touching call sites.
nonisolated struct StubGearSearchProvider: GearSearchProviding {

    private let gears: [GearOption]

    init(gears: [GearOption] = [.seineNets]) {
        self.gears = gears
    }

    func allGears() async throws -> [GearOption] {
        gears
    }
}
