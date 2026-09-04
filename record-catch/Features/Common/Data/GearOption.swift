import Foundation

/// A gear (fishing method) the user can search for and save as a favourite.
///
/// API-shaped value type mirroring `PortOption` (see ADR-0004). The gear list is a future API;
/// stubbed for now with the full fishing-gear reference catalogue (see ADR-0012). A gear defines
/// two kinds of measurement, both supplied by the future gear reference data:
/// - `requiredMeasurements` — fixed properties of the gear itself (e.g. mesh size for seine nets),
///   captured once when the user adds the gear to their favourites.
/// - `variableMeasurements` — values that can change per trip (e.g. the number of times the gear
///   was shot), captured on the "What gear did you use?" screen each time the gear is used.
/// Each is modelled as an ordered list because a gear can define several of either, or none at all
/// (e.g. "Mechanised dredges" / "Miscellaneous gear (diving)" define no measurements — see
/// `AddGearViewModel.submit()`, which skips the now-empty measurements screen for such a gear).
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

    /// Convenience for ad hoc/test gears, where the name is also the stable identifier.
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

/// Shared, de-duplicated measurement definitions reused across the gear catalogue (see ADR-0012),
/// so the same question ("Mesh size (mm)", "Number of trawl nets", …) is declared exactly once
/// rather than repeated per gear.
extension GearMeasurement {

    // MARK: Required (per-favourite) measurements

    static let meshSize = GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize")
    static let numberOfBeams = GearMeasurement(id: "numberOfBeams", labelKey: "catchRecord.gear.measurement.numberOfBeams")
    static let numberOfTrawlNets = GearMeasurement(id: "numberOfTrawlNets", labelKey: "catchRecord.gear.measurement.numberOfTrawlNets")
    static let numberOfDredges = GearMeasurement(id: "numberOfDredges", labelKey: "catchRecord.gear.measurement.numberOfDredges")
    static let numberOfBeamsOrTrawls = GearMeasurement(id: "numberOfBeamsOrTrawls", labelKey: "catchRecord.gear.measurement.numberOfBeamsOrTrawls")

    // MARK: Variable (per-trip) measurements

    static let timesShot = GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot")
    static let netLengthHauled = GearMeasurement(id: "netLengthHauled", labelKey: "catchRecord.gear.variableMeasurement.netLengthHauled")
    static let netLengthLeft = GearMeasurement(id: "netLengthLeft", labelKey: "catchRecord.gear.variableMeasurement.netLengthLeft")
    static let hooksHauled = GearMeasurement(id: "hooksHauled", labelKey: "catchRecord.gear.variableMeasurement.hooksHauled")
    static let hooksLeft = GearMeasurement(id: "hooksLeft", labelKey: "catchRecord.gear.variableMeasurement.hooksLeft")
    static let rodsAndLines = GearMeasurement(id: "rodsAndLines", labelKey: "catchRecord.gear.variableMeasurement.rodsAndLines")
    static let potsHauled = GearMeasurement(id: "potsHauled", labelKey: "catchRecord.gear.variableMeasurement.potsHauled")
    static let potsLeft = GearMeasurement(id: "potsLeft", labelKey: "catchRecord.gear.variableMeasurement.potsLeft")
}

extension GearOption {
    /// Seine nets — kept as a named handle for previews/tests (widely referenced before the full
    /// catalogue existed). Requires a mesh size (fixed) and, per trip, captures the number of times
    /// the gear was shot. Also appears in `all` below.
    static let seineNets = GearOption(
        id: "SX",
        name: "Seine nets (not specified)",
        requiredMeasurements: [.meshSize],
        variableMeasurements: [.timesShot]
    )

    /// The full fishing-gear reference-data catalogue (see ADR-0012), standing in for the future
    /// gear reference-data API behind the existing ADR-0004 stub seam. `id` is the stable FAO gear
    /// code. A gear with no measurements at all (e.g. `HMD`, `MIS`) defines neither list; selecting
    /// one skips straight to favourites (see `AddGearViewModel.submit()`) and reveals no per-trip
    /// field on the select-gear screen.
    static let all: [GearOption] = [
        GearOption(id: "TBB", name: "Beam trawl", requiredMeasurements: [.meshSize, .numberOfBeams], variableMeasurements: [.timesShot]),
        GearOption(id: "SV", name: "Boat or vessel seine", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
        GearOption(id: "OTB", name: "Bottom otter trawl", requiredMeasurements: [.meshSize, .numberOfTrawlNets], variableMeasurements: [.timesShot]),
        GearOption(id: "PTB", name: "Bottom pair trawl", requiredMeasurements: [.meshSize, .numberOfTrawlNets], variableMeasurements: [.timesShot]),
        GearOption(id: "TB", name: "Bottom trawls (not specified)", requiredMeasurements: [.meshSize, .numberOfTrawlNets], variableMeasurements: [.timesShot]),
        GearOption(id: "GTN", name: "Combined gillnets-trammel nets", requiredMeasurements: [.meshSize], variableMeasurements: [.netLengthHauled, .netLengthLeft]),
        GearOption(id: "SDN", name: "Danish anchor seine", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
        GearOption(id: "DRB", name: "Dredge", requiredMeasurements: [.numberOfDredges], variableMeasurements: [.timesShot]),
        GearOption(id: "LLD", name: "Drifting longlines", variableMeasurements: [.hooksHauled, .hooksLeft]),
        GearOption(id: "GNC", name: "Gillnets (circling)", requiredMeasurements: [.meshSize], variableMeasurements: [.netLengthHauled, .netLengthLeft]),
        GearOption(id: "GND", name: "Gillnets (drift)", requiredMeasurements: [.meshSize], variableMeasurements: [.netLengthHauled, .netLengthLeft]),
        GearOption(id: "GN", name: "Gillnets (not specified)", requiredMeasurements: [.meshSize], variableMeasurements: [.netLengthHauled, .netLengthLeft]),
        GearOption(id: "GNS", name: "Gillnets anchored (set)", requiredMeasurements: [.meshSize], variableMeasurements: [.netLengthHauled, .netLengthLeft]),
        GearOption(id: "LHP", name: "Handlines and pole lines (hand operated)", variableMeasurements: [.rodsAndLines]),
        GearOption(id: "LHM", name: "Handlines and pole lines (mechanised)", variableMeasurements: [.rodsAndLines]),
        GearOption(id: "LX", name: "Hooks and lines (not specified)", variableMeasurements: [.hooksHauled, .hooksLeft]),
        GearOption(id: "LL", name: "Longlines not specified", variableMeasurements: [.hooksHauled, .hooksLeft]),
        GearOption(id: "HMD", name: "Mechanised dredges"),
        GearOption(id: "OTM", name: "Mid-water otter trawl", requiredMeasurements: [.meshSize, .numberOfTrawlNets], variableMeasurements: [.timesShot]),
        GearOption(id: "PTM", name: "Mid-water pair trawl", requiredMeasurements: [.meshSize, .numberOfTrawlNets], variableMeasurements: [.timesShot]),
        GearOption(id: "MIS", name: "Miscellaneous gear (diving)"),
        GearOption(id: "TBN", name: "Nephrops trawls", requiredMeasurements: [.meshSize, .numberOfTrawlNets], variableMeasurements: [.timesShot]),
        GearOption(id: "OTT", name: "Otter twin trawls", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
        GearOption(id: "FPO", name: "Pots", variableMeasurements: [.potsHauled, .potsLeft]),
        GearOption(id: "PS", name: "Purse seine", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
        GearOption(id: "SPR", name: "Scottish pair seine (fly dragging)", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
        GearOption(id: "SSC", name: "Scottish seine (fly dragging)", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
        .seineNets,
        GearOption(id: "LLS", name: "Set longlines", variableMeasurements: [.hooksHauled, .hooksLeft]),
        GearOption(id: "TBS", name: "Shrimp trawls", requiredMeasurements: [.meshSize, .numberOfBeamsOrTrawls], variableMeasurements: [.timesShot]),
        GearOption(id: "SUX", name: "Surrounding nets (Ring Net)", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
        GearOption(id: "GTR", name: "Trammel net", requiredMeasurements: [.meshSize], variableMeasurements: [.netLengthHauled, .netLengthLeft]),
        GearOption(id: "FIX", name: "Traps (not specified)", variableMeasurements: [.potsHauled, .potsLeft]),
        GearOption(id: "LTL", name: "Trolling lines", variableMeasurements: [.hooksHauled, .hooksLeft]),
        GearOption(id: "PS2", name: "Two boat operated purse seine", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
        GearOption(id: "LA", name: "Without purse lines (lampara)", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot]),
    ]
}
