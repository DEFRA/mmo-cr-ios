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
nonisolated struct GearOption: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    /// Fixed measurements of the gear, captured when it is added to favourites (empty until captured).
    let requiredMeasurements: [GearMeasurement]
    /// Per-trip measurements, captured on the select-gear screen (values `nil` until captured).
    let variableMeasurements: [GearMeasurement]
    /// The reference-data API's own GUID for this gear, when sourced from
    /// `GearOption.make(canonical:mobile:measurementsById:vesselLengthBand:)` (see ADR-0024 "Gears
    /// from two requests"). `nil` for
    /// every other source (the bundled ADR-0012 catalogue, hand-built test/demo values) — kept as
    /// an **optional** type (not a non-optional default) so previously-persisted favourites that
    /// predate this field still decode via the synthesized `Codable` conformance, matching
    /// `PortOption`'s established pattern for the same situation.
    let referenceId: String?
    /// The API's stable category code (e.g. `"TRAWL_NETS"`), when sourced from `init(dto:)`. `nil`
    /// for every other source.
    let categoryCode: String?
    /// The API's display name for the category (e.g. `"Trawl nets"`), when sourced from
    /// `init(dto:)`. `nil` for every other source.
    let categoryName: String?
    /// Whether this gear is used in pairs (e.g. pair trawls, two-boat purse seine), when sourced
    /// from `init(dto:)`. `nil` for every other source.
    let isPairFishing: Bool?

    /// Groups this gear's optional, API-sourced-only fields (`referenceId`/`categoryCode`/
    /// `categoryName`/`isPairFishing`) so the designated initializer stays within Sonar's
    /// `swift:S107` parameter-count limit (7) — this is a pure regrouping of constructor
    /// arguments; the four fields remain flat stored properties on `GearOption` itself (and keep
    /// their existing `Codable` keys) so previously-persisted favourites still decode unchanged.
    struct APIMetadata: Hashable, Sendable {
        let referenceId: String?
        let categoryCode: String?
        let categoryName: String?
        let isPairFishing: Bool?

        /// No API metadata — the bundled ADR-0012 catalogue and hand-built test/demo gears.
        static let none = APIMetadata(referenceId: nil, categoryCode: nil, categoryName: nil, isPairFishing: nil)

        init(
            referenceId: String? = nil,
            categoryCode: String? = nil,
            categoryName: String? = nil,
            isPairFishing: Bool? = nil
        ) {
            self.referenceId = referenceId
            self.categoryCode = categoryCode
            self.categoryName = categoryName
            self.isPairFishing = isPairFishing
        }
    }

    init(
        id: String,
        name: String,
        requiredMeasurements: [GearMeasurement] = [],
        variableMeasurements: [GearMeasurement] = [],
        apiMetadata: APIMetadata = .none
    ) {
        self.id = id
        self.name = name
        self.requiredMeasurements = requiredMeasurements
        self.variableMeasurements = variableMeasurements
        self.referenceId = apiMetadata.referenceId
        self.categoryCode = apiMetadata.categoryCode
        self.categoryName = apiMetadata.categoryName
        self.isPairFishing = apiMetadata.isPairFishing
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

    /// This gear's current API metadata, bundled back up for `withRequiredMeasurements(_:)`/
    /// `withVariableMeasurements(_:)` to pass straight through unchanged.
    private var apiMetadata: APIMetadata {
        APIMetadata(
            referenceId: referenceId,
            categoryCode: categoryCode,
            categoryName: categoryName,
            isPairFishing: isPairFishing
        )
    }

    /// Returns a copy of this gear with the given required (per-favourite) measurements attached.
    func withRequiredMeasurements(_ measurements: [GearMeasurement]) -> GearOption {
        GearOption(
            id: id,
            name: name,
            requiredMeasurements: measurements,
            variableMeasurements: variableMeasurements,
            apiMetadata: apiMetadata
        )
    }

    /// Returns a copy of this gear with the given variable (per-trip) measurements attached.
    func withVariableMeasurements(_ measurements: [GearMeasurement]) -> GearOption {
        GearOption(
            id: id,
            name: name,
            requiredMeasurements: requiredMeasurements,
            variableMeasurements: measurements,
            apiMetadata: apiMetadata
        )
    }

    /// This gear's name followed by its captured required (per-favourite) measurements in
    /// parentheses, e.g. "Seine nets (mesh size 100mm)" — used to build headings such as "Where was
    /// the majority of your catch caught using Seine nets (mesh size 100mm)?" (see
    /// docs/design-specs/create-catch-record.md).
    ///
    /// Measurements with no captured value yet, or with no `shortDescriptionKey`, are skipped;
    /// several are joined with ", ". Returns the gear name alone when no measurement can be
    /// described — e.g. before any required measurement has been captured, or for a gear
    /// (`HMD`/`MIS`) that defines none at all.
    ///
    /// - Parameter localize: resolves a String Catalog key to its localised format string (see
    ///   `AppLanguageStore.localized(_:)`). Taken as a closure rather than an `AppLanguageStore`
    ///   dependency so this pure data model stays environment-agnostic and unit-testable.
    func descriptionWithMeasurements(localize: (String) -> String) -> String {
        let parts = requiredMeasurements.compactMap { measurement -> String? in
            guard let value = measurement.value, let key = measurement.shortDescriptionKey else { return nil }
            return String(format: localize(key), value)
        }
        guard !parts.isEmpty else { return name }
        return "\(name) (\(parts.joined(separator: ", ")))"
    }

    /// This gear's captured required measurements as a single, already-localised checkbox-subtitle
    /// line (e.g. "100mm mesh" for seine nets, "80mm mesh, 2 trawl nets" for a gear with several),
    /// matching the approved Select-gear and Remove-gear designs exactly (see
    /// `docs/design-specs/create-catch-record.md`). Generic across the whole catalogue via
    /// `GearMeasurement.checklistSubtitleKey`, not mesh-size-specific. `nil` when no required
    /// measurement has a captured value yet, or the gear defines none at all.
    ///
    /// - Parameter localize: resolves a String Catalog key to its localised format string (see
    ///   `descriptionWithMeasurements(localize:)`, which this mirrors).
    func checklistSubtitle(localize: (String) -> String) -> String? {
        let parts = requiredMeasurements.compactMap { measurement -> String? in
            guard let value = measurement.value, let key = measurement.checklistSubtitleKey else { return nil }
            return String(format: localize(key), value)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

/// A single measurement for a gear (required or variable).
///
/// Modelled generically so a gear can define one or many of each kind. `value` is `nil` until the
/// user enters it. Measurements are whole numbers per the design ("All gear measurements must be
/// whole numbers").
nonisolated struct GearMeasurement: Identifiable, Hashable, Sendable, Codable {
    let id: String
    /// String Catalog key for the field label (e.g. "Mesh size (mm)") for the bundled ADR-0012
    /// catalogue. When sourced from `GearOption.make(canonical:mobile:measurementsById:vesselLengthBand:)`,
    /// this instead holds the API's own (unlocalised, English-only) `label` text verbatim — except
    /// for a generic, multi-example "gear dimension" label, which is replaced with a specific,
    /// localized String Catalog key derived from the gear's own name (see
    /// `GearOption.isGenericDimensionLabel(_:)`/`specificDimensionLabelKey(forGearNamed:fallback:)`).
    /// See `GearOption.make`'s doc comment and the ADR-0018 addendum "gears dataset" for the wider
    /// known gap this is a targeted fix for (most backend labels still aren't String Catalog keys).
    let labelKey: String
    /// The whole-number value the user entered, or `nil` if not yet captured.
    let value: Int?
    /// The reference-data API's own short code for this measurement (e.g. `"ME"` for mesh size),
    /// when sourced from `GearOption.make(canonical:mobile:measurementsById:vesselLengthBand:)`.
    /// `nil` for every other source.
    let apiCode: String?
    /// The API's unit for this measurement (e.g. `"mm"`, `"m"`, `"count"`), when sourced from
    /// `GearOption.make(canonical:mobile:measurementsById:vesselLengthBand:)`. `nil` for every
    /// other source.
    let unit: String?

    init(id: String, labelKey: String, value: Int? = nil, apiCode: String? = nil, unit: String? = nil) {
        self.id = id
        self.labelKey = labelKey
        self.value = value
        self.apiCode = apiCode
        self.unit = unit
    }

    /// Returns a copy of this measurement with the given value.
    func withValue(_ value: Int?) -> GearMeasurement {
        GearMeasurement(id: id, labelKey: labelKey, value: value, apiCode: apiCode, unit: unit)
    }

    /// String Catalog key for this measurement's short, parenthetical description (e.g. "mesh size
    /// %dmm"), used to build a gear's full description — see
    /// `GearOption.descriptionWithMeasurements(localize:)`. `nil` for measurements with no defined
    /// short form (currently all per-trip "variable" measurements, whose labels are full sentences
    /// unsuited to a parenthetical).
    var shortDescriptionKey: String? {
        switch id {
        case "meshSize": return "catchRecord.gear.measurementShort.meshSize"
        case "numberOfBeams": return "catchRecord.gear.measurementShort.numberOfBeams"
        case "numberOfTrawlNets": return "catchRecord.gear.measurementShort.numberOfTrawlNets"
        case "numberOfDredges": return "catchRecord.gear.measurementShort.numberOfDredges"
        case "numberOfBeamsOrTrawls": return "catchRecord.gear.measurementShort.numberOfBeamsOrTrawls"
        default: return nil
        }
    }

    /// String Catalog key for this measurement's short form as shown in a Select-gear/Remove-gear
    /// checkbox subtitle (e.g. "100mm mesh" for a captured mesh size of 100) — matches the approved
    /// Figma ("Gear selection") and web ("Remove gear") designs exactly (see
    /// `docs/design-specs/create-catch-record.md`). Differs from `shortDescriptionKey` (used in
    /// question headings, e.g. "mesh size 100mm") only for mesh size, where the two orderings
    /// differ; every other measurement's short form already reads correctly in both places and
    /// reuses the same key. `nil` for measurements with no defined short form (mirrors
    /// `shortDescriptionKey`).
    var checklistSubtitleKey: String? {
        id == "meshSize" ? "catchRecord.gear.measurementSubtitle.meshSize" : shortDescriptionKey
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
        GearOption(id: "LA", name: "Without purse lines (lampara)", requiredMeasurements: [.meshSize], variableMeasurements: [.timesShot])
    ]
}

extension GearOption {
    /// The only vessel-length band the app currently asks gear questions for (see ADR-0024
    /// "Vessel-length scope"): every vessel is treated as under 10m for now, regardless of its
    /// real `lengthOverallMetres`. The live API's `applicableCharacteristics.vesselLengthApplicability`
    /// carries other bands (`"10-to-12m"`, `"over-12m"`) that this connector deliberately ignores
    /// until per-vessel banding is built — revisit this constant, not the join logic below, when
    /// that happens.
    static let currentVesselLengthBand = "under-10m"

    /// Keyword → bundled String Catalog label key, used to replace a generic, multi-example live
    /// reference-data measurement label with one specific to the gear it is attached to. Order
    /// matters: the first keyword found in the gear's own name wins, and "trawl" deliberately comes
    /// **last** — gear names like "Beam trawl" contain both "beam" and "trawl", and the more
    /// specific gear-type keyword must win over the generic one. See
    /// `isGenericDimensionLabel(_:)`/`specificDimensionLabelKey(forGearNamed:fallback:)` for why
    /// this exists.
    private static let dimensionKeywordLabelKeys: [(keyword: String, labelKey: String)] = [
        ("beam", "catchRecord.gear.measurement.numberOfBeams"),
        ("dredge", "catchRecord.gear.measurement.numberOfDredges"),
        ("pot", "catchRecord.gear.measurement.numberOfPots"),
        ("hook", "catchRecord.gear.measurement.numberOfHooks"),
        ("trawl", "catchRecord.gear.measurement.numberOfTrawls")
    ]

    /// Whether a live reference-data measurement definition's label is the backend's shared,
    /// multi-example "gear dimension" description (e.g. "Gear dimension by number. For example:
    /// number of trawls, number of beams, number of dredges, number of pots, number of hooks")
    /// rather than a specific one like "Mesh size (mm)" or "Number of beams" (see the
    /// `gears-mobile-response.json` fixture for an example of the latter, specific shape). Several
    /// gear types can share one backend measurement definition id, so the definition's own label
    /// is sometimes written to cover every one of them at once — detected structurally (it
    /// mentions at least two of the known "number of <word>" examples) rather than by matching the
    /// exact sentence, so this survives minor backend wording changes. Tracked as a known gap in
    /// ADR-0024/`docs/api/reference-data-api.md` ("Measurement labels are the API's plain English
    /// text, not yet a String Catalog key") — this is a targeted, gear-name-derived fix for that
    /// gap's most visible case, not a full resolution of it.
    private static func isGenericDimensionLabel(_ label: String) -> Bool {
        let lowercased = label.lowercased()
        let matchCount = dimensionKeywordLabelKeys.filter { lowercased.contains("number of \($0.keyword)") }.count
        return matchCount >= 2
    }

    /// Resolves a specific, localized String Catalog key for a generic "gear dimension"
    /// measurement by matching the gear's own name against known keywords (trawl/beam/dredge/pot/
    /// hook) — e.g. "Shrimp trawls" resolves to "Number of trawls", not the raw backend text
    /// enumerating every gear family that happens to share the one backend measurement
    /// definition. Falls back to the generic label unchanged when no keyword matches, so an
    /// unrecognised gear never loses its (if unhelpful) label entirely — `AppLanguageStore.localized(_:)`
    /// already degrades gracefully by returning an unknown key's text verbatim.
    private static func specificDimensionLabelKey(forGearNamed gearName: String, fallback: String) -> String {
        let lowercasedName = gearName.lowercased()
        return dimensionKeywordLabelKeys.first { lowercasedName.contains($0.keyword) }?.labelKey ?? fallback
    }

    /// Joins a gear's **canonical**-view record (`GearCanonicalDTO`, the source of the
    /// required/per-trip split via `applicableCharacteristics.fixed`) with its **mobile**-view
    /// record (`GearMobileDTO`, the source of category/pair-fishing display fields) and the
    /// mobile response's `measurements` catalogue (the source of labels/units) — see ADR-0024
    /// "Gears from two requests".
    ///
    /// `id` is the API's `code` (the stable FAO gear code, e.g. `"TBB"`) — **not** the API's GUID
    /// (kept separately as `referenceId`) — so favourites keyed on the gear code (ADR-0012) are
    /// unaffected by this connector.
    ///
    /// Only characteristics whose `vesselLengthApplicability` includes `vesselLengthBand`
    /// (default `currentVesselLengthBand`) are kept; `fixed: true` becomes a required (per-
    /// favourite) measurement, `fixed: false` becomes a variable (per-trip) one. A gear with no
    /// characteristic applicable to that band (e.g. every hook-and-line/pot gear under 10m, per
    /// ADR-0024) defines neither list — `AddGearViewModel.submit()` already saves such a gear
    /// straight to favourites, skipping the now-empty measurements screen.
    ///
    /// - Throws: `ReferenceDataValidationError.unresolvedGearMeasurement` if a kept characteristic
    ///   references a measurement id absent from `measurementsById` — this is strict (ADR-0024
    ///   "Validation"): the whole gear is rejected rather than silently dropping the question, so
    ///   a bad response can never persist to the favourite catalogue.
    static func make(
        canonical: GearCanonicalDTO,
        mobile: GearMobileDTO,
        measurementsById: [String: GearMeasurementDefinitionDTO],
        vesselLengthBand: String = currentVesselLengthBand
    ) throws -> GearOption {
        let applicable = (canonical.applicableCharacteristics ?? []).filter {
            ($0.vesselLengthApplicability ?? []).contains(vesselLengthBand)
        }

        func measurement(for characteristic: GearCharacteristicDTO) throws -> GearMeasurement {
            guard let definition = measurementsById[characteristic.characteristicId] else {
                throw ReferenceDataValidationError.unresolvedGearMeasurement(
                    gearCode: canonical.code,
                    measurementId: characteristic.characteristicId
                )
            }
            let labelKey = isGenericDimensionLabel(definition.label)
                ? specificDimensionLabelKey(forGearNamed: canonical.name, fallback: definition.label)
                : definition.label
            return GearMeasurement(
                id: definition.id,
                labelKey: labelKey,
                apiCode: definition.code,
                unit: definition.unit
            )
        }

        let requiredMeasurements = try applicable.filter(\.fixed).map(measurement(for:))
        let variableMeasurements = try applicable.filter { !$0.fixed }.map(measurement(for:))

        return GearOption(
            id: canonical.code,
            name: canonical.name,
            requiredMeasurements: requiredMeasurements,
            variableMeasurements: variableMeasurements,
            apiMetadata: APIMetadata(
                referenceId: canonical.id,
                categoryCode: mobile.category?.code,
                categoryName: mobile.category?.name,
                isPairFishing: mobile.pairFishing ?? canonical.pairFishing
            )
        )
    }
}
