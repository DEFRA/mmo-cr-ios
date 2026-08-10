import Foundation

/// A port the user can search for and save as a favourite.
///
/// API-shaped value type (see ADR-0004). `id` is stable so a real API-backed provider can supply
/// server identifiers without changing call sites; `name` is the display string.
///
/// Explicitly `nonisolated` so it can be constructed and read from any actor context (the stubbed
/// providers run off the main actor); a plain `Sendable` value type has no isolation needs.
nonisolated struct PortOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    /// Convenience for the current stub, where the name is also the stable identifier.
    init(name: String) {
        self.id = name
        self.name = name
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
