import Foundation

/// A gear (fishing method) the user can search for and save as a favourite.
///
/// API-shaped value type mirroring `PortOption` (see ADR-0004). The gear list is a future API;
/// stubbed for now. A gear defines two kinds of measurement, both supplied by the future gear
/// reference data:
/// - `requiredMeasurements` — fixed properties of the gear itself (e.g. mesh size for seine nets),
///   captured once when the user adds the gear to their favourites.
/// - `variableMeasurements` — values that can change per trip (e.g. the number of times the gear
///   was shot), captured on the "What gear did you use?" screen each time the gear is used.
/// Each is modelled as an ordered list because a gear can define several of either.
nonisolated struct GearOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Fixed measurements of the gear, captured when it is added to favourites (empty until captured).
    let requiredMeasurements: [GearMeasurement]
    /// Per-trip measurements, captured on the select-gear screen (values `nil` until captured).
    let variableMeasurements: [GearMeasurement]

    init(
        id: String,
        name: String,
        requiredMeasurements: [GearMeasurement] = [],
        variableMeasurements: [GearMeasurement] = []
    ) {
        self.id = id
        self.name = name
        self.requiredMeasurements = requiredMeasurements
        self.variableMeasurements = variableMeasurements
    }

    /// Convenience for the current stub, where the name is also the stable identifier.
    init(
        name: String,
        requiredMeasurements: [GearMeasurement] = [],
        variableMeasurements: [GearMeasurement] = []
    ) {
        self.init(
            id: name,
            name: name,
            requiredMeasurements: requiredMeasurements,
            variableMeasurements: variableMeasurements
        )
    }

    /// Returns a copy of this gear with the given required (per-favourite) measurements attached.
    func withRequiredMeasurements(_ measurements: [GearMeasurement]) -> GearOption {
        GearOption(
            id: id,
            name: name,
            requiredMeasurements: measurements,
            variableMeasurements: variableMeasurements
        )
    }

    /// Returns a copy of this gear with the given variable (per-trip) measurements attached.
    func withVariableMeasurements(_ measurements: [GearMeasurement]) -> GearOption {
        GearOption(
            id: id,
            name: name,
            requiredMeasurements: requiredMeasurements,
            variableMeasurements: measurements
        )
    }
}

/// A single measurement for a gear (required or variable).
///
/// Modelled generically so a gear can define one or many of each kind. `value` is `nil` until the
/// user enters it. Measurements are whole numbers per the design ("All gear measurements must be
/// whole numbers").
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
    /// Seine nets — the single gear implemented in this phase. Requires a mesh size (fixed) and, per
    /// trip, captures the number of times the gear was shot.
    static let seineNets = GearOption(
        name: "Seine nets (not specified)",
        requiredMeasurements: [
            GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize")
        ],
        variableMeasurements: [
            GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot")
        ]
    )
}
