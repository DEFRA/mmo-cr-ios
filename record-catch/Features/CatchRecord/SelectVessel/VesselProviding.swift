import Foundation

/// Supplies the vessels a user can pick from on the Select vessel screen.
///
/// A protocol so a future API-backed implementation can swap in without changing
/// `SelectVesselViewModel` or its tests.
protocol VesselProviding {
    var vessels: [String] { get }

    /// The RSS (Registry of Shipping and Seamen) number for the vessel named `name`, used to build
    /// the catch record reference the moment a vessel is selected (see
    /// `CatchRecordReferenceGenerator`, ADR-0026). `nil` when `name` is not a known vessel, or when
    /// this provider has no RSS number for it.
    ///
    /// Defaulted to always return `nil` (see the extension below) so existing conformers (e.g.
    /// `StubVesselProvider` in tests) are unaffected by this requirement's addition.
    func rssNumber(forVesselNamed name: String) -> String?
}

extension VesselProviding {
    func rssNumber(forVesselNamed _: String) -> String? { nil }
}

/// Static, UI-only vessel list. Stands in until a real vessel API/service exists.
nonisolated struct StaticVesselProvider: VesselProviding {
    let vessels: [String] = ["ACHILLES", "HERCULES"]

    /// Fake RSS numbers for the two static demo vessels, so the catch-record reference generator
    /// (ADR-0026) has something to build from ahead of a real vessel API/service existing.
    private static let rssNumbersByVesselName: [String: String] = [
        "ACHILLES": "A12345",
        "HERCULES": "H54321"
    ]

    func rssNumber(forVesselNamed name: String) -> String? {
        Self.rssNumbersByVesselName[name]
    }
}
