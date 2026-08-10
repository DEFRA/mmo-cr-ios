import Foundation

/// A gear (fishing method) the user can search for and save as a favourite.
///
/// API-shaped value type mirroring `PortOption` (see ADR-0004). The gear list is a future API;
/// stubbed for now. `measurements` captures the user-entered measurements for this gear (e.g. mesh
/// size for seine nets) — a gear can require several, so it is modelled as an ordered list.
nonisolated struct GearOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// The measurements the user entered for this gear (empty until captured).
    let measurements: [GearMeasurement]

    init(id: String, name: String, measurements: [GearMeasurement] = []) {
        self.id = id
        self.name = name
        self.measurements = measurements
    }

    /// Convenience for the current stub, where the name is also the stable identifier.
    init(name: String, measurements: [GearMeasurement] = []) {
        self.init(id: name, name: name, measurements: measurements)
    }

    /// Returns a copy of this gear with the given measurements attached.
    func withMeasurements(_ measurements: [GearMeasurement]) -> GearOption {
        GearOption(id: id, name: name, measurements: measurements)
    }
}

/// A single required measurement for a gear.
///
/// Modelled generically so a gear can define one or many (seine nets need only a mesh size, but
/// other gears require several). `value` is `nil` until the user enters it. Measurements are whole
/// numbers per the design ("All gear measurements must be whole numbers").
nonisolated struct GearMeasurement: Identifiable, Hashable, Sendable {
    let id: String
    /// String Catalog key for the field label (e.g. "Mesh size (mm)").
    let labelKey: String
    /// The whole-number value the user entered, or `nil` if not yet captured.
    let value: Int?

    init(id: String, labelKey: String, value: Int? = nil) {
        self.id = id
        self.labelKey = labelKey
        self.value = value
    }

    /// Returns a copy of this measurement with the given value.
    func withValue(_ value: Int?) -> GearMeasurement {
        GearMeasurement(id: id, labelKey: labelKey, value: value)
    }
}

extension GearOption {
    /// Seine nets — the single gear implemented in this phase. Requires one measurement (mesh size).
    static let seineNets = GearOption(
        name: "Seine nets (not specified)",
        measurements: [GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize")]
    )
}
