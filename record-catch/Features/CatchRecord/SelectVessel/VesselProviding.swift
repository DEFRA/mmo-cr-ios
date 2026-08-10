import Foundation

/// Supplies the vessels a user can pick from on the Select vessel screen.
///
/// A protocol so a future API-backed implementation can swap in without changing
/// `SelectVesselViewModel` or its tests.
protocol VesselProviding {
    var vessels: [String] { get }
}

/// Static, UI-only vessel list. Stands in until a real vessel API/service exists.
nonisolated struct StaticVesselProvider: VesselProviding {
    let vessels: [String] = ["ACHILLES", "HERCULES"]
}
