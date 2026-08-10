import Foundation

/// Supplies the species a user can search for on the Add-species screen.
///
/// API-shaped: `async throws` so a future real Species API can swap in without changing
/// `AddSpeciesViewModel` or its tests (see ADR-0004). Stubbed for now.
nonisolated protocol SpeciesSearchProviding: Sendable {
    /// Species whose name contains `query` (case-insensitive), or an empty list when `query` is
    /// shorter than `minimumCharacters`.
    func searchSpecies(matching query: String) async throws -> [SpeciesOption]

    /// The full set of species, used to seed a locally-filtering search field. A real API-backed
    /// implementation may page or cache; the stub returns its static list.
    func allSpecies() async throws -> [SpeciesOption]
}

/// Static, UI-only species search. Stands in until a real Species API exists.
///
/// Mirrors `StubPortSearchProvider`: a deterministic in-memory list with a minimum-characters
/// threshold before results appear.
nonisolated struct StubSpeciesSearchProvider: SpeciesSearchProviding {

    /// Minimum characters before any results are returned (matches the search field's default).
    let minimumCharacters: Int
    private let species: [SpeciesOption]

    init(
        minimumCharacters: Int = 2,
        names: [String] = StubSpeciesSearchProvider.defaultNames
    ) {
        self.minimumCharacters = minimumCharacters
        self.species = names.map(SpeciesOption.init(name:))
    }

    /// The stubbed UK species list for this phase.
    static let defaultNames = [
        "Atlantic cod (COD)",
        "Edible crab (CRE)",
        "Salmon (SAL)",
        "European lobster (LBE)",
        "Common sole (SOL)",
        "Plaice (PLE)",
        "Herring (HER)",
        "Mackerel (MAC)"
    ]

    func searchSpecies(matching query: String) async throws -> [SpeciesOption] {
        Self.filtered(query: query, minimumCharacters: minimumCharacters, species: species)
    }

    func allSpecies() async throws -> [SpeciesOption] {
        species
    }

    /// Pure filtering, exposed for unit testing without awaiting the async surface.
    static func filtered(
        query: String,
        minimumCharacters: Int,
        species: [SpeciesOption]
    ) -> [SpeciesOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumCharacters else { return [] }
        return species.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
