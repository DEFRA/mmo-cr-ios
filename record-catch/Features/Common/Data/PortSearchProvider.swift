import Foundation

/// Supplies the ports a user can search for on the Add-port screen.
///
/// API-shaped: `async throws` so a future real Ports API can swap in without changing
/// `AddPortViewModel` or its tests (see ADR-0004). Stubbed for now.
nonisolated protocol PortSearchProviding: Sendable {
    /// Ports whose name contains `query` (case-insensitive), or an empty list when `query` is
    /// shorter than `minimumCharacters`.
    func searchPorts(matching query: String) async throws -> [PortOption]

    /// The full set of ports, used to seed a locally-filtering search field. A real API-backed
    /// implementation may page or cache; the stub returns its static list.
    func allPorts() async throws -> [PortOption]
}

/// Static, UI-only port search. Stands in until a real Ports API exists.
///
/// Reuses the same UK port list as the synchronous `StubPortOptionProvider` so the existing
/// `SearchDropdownField` demo/tests are unaffected.
nonisolated struct StubPortSearchProvider: PortSearchProviding {

    /// Minimum characters before any results are returned (matches the search field's default).
    let minimumCharacters: Int
    private let ports: [PortOption]

    init(minimumCharacters: Int = 2, names: [String] = StubPortOptionProvider().options) {
        self.minimumCharacters = minimumCharacters
        self.ports = names.map(PortOption.init(name:))
    }

    func searchPorts(matching query: String) async throws -> [PortOption] {
        Self.filtered(query: query, minimumCharacters: minimumCharacters, ports: ports)
    }

    func allPorts() async throws -> [PortOption] {
        ports
    }

    /// Pure filtering, exposed for unit testing without awaiting the async surface.
    static func filtered(query: String, minimumCharacters: Int, ports: [PortOption]) -> [PortOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumCharacters else { return [] }
        return ports.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
