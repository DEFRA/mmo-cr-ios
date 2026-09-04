import Foundation

/// Supplies the gears a user can search for on the Add-gear screen.
///
/// API-shaped: `async throws` so a future real Gear API can swap in without changing the view model
/// or its tests (see ADR-0004). Stubbed for now — seeded with the full fishing-gear reference
/// catalogue (`GearOption.all`, see ADR-0012).
nonisolated protocol GearSearchProviding: Sendable {
    /// The full set of searchable gears, used to seed a locally-filtering search field.
    func allGears() async throws -> [GearOption]
}

/// Static, UI-only gear search. Stands in until a real Gear API exists.
///
/// Seeded with the full gear catalogue (see ADR-0012); additional/changed gears with their own
/// measurements can be added to `GearOption.all` without touching call sites.
nonisolated struct StubGearSearchProvider: GearSearchProviding {

    private let gears: [GearOption]

    init(gears: [GearOption] = GearOption.all) {
        self.gears = gears
    }

    func allGears() async throws -> [GearOption] {
        gears
    }
}
