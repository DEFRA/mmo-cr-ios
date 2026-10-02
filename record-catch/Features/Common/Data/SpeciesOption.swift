import Foundation

/// A species the user can search for, save as a favourite, and record weights against.
///
/// API-shaped value type mirroring `GearOption`/`PortOption`/`VesselOption` (see ADR-0004,
/// ADR-0018). Carries every field the reference-data API's `species` dataset canonical view
/// exposes (`faoCode`, `scientificName`, `commonNames`, `localNames`, `isActive` — see
/// `init(dto:)`), alongside the three optional weights that capture the user-entered live weights
/// in kilograms for this species: `weightAboveMinimumKg` is always available once a species is
/// recorded, while `weightBelowMinimumKg` and `weightLegallyDiscardedKg` are optional extras the
/// user can reveal. Weights are held as the raw entered strings for this phase — numeric
/// validation is applied by `SpeciesWeightValidation`, keyed off `weightPrecision`.
///
/// This is the second domain type (after `VesselOption`) mapped from a *real* reference-data
/// network response; the stubbed `StubSpeciesSearchProvider`/`FavouriteSpeciesProviding` seams are
/// **not** wired to it in this change — see the ADR-0018 addendum for the connector-only scope.
///
/// This is this app's own `Codable` shape, not a passthrough of the wire format (see `SpeciesDTO`),
/// so it is **not** guaranteed to decode a payload written by a previous version of this type —
/// there is deliberately no backwards-compatibility seam for the species shape going forward.
///
/// Explicitly `nonisolated` so it can be constructed and read from any actor context (the stubbed
/// providers run off the main actor); a plain `Sendable` value type has no isolation needs.
nonisolated struct SpeciesOption: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    /// The FAO 3-alpha species code (e.g. `"COD"`), when supplied by the API.
    let faoCode: String?
    /// The species' scientific/Latin name, when supplied by the API.
    let scientificName: String?
    /// Localised common names for this species, flattened from the API's `commonNames` array.
    /// Empty (never a decoding failure) when the API omits or empties the array.
    let commonNames: [SpeciesName]
    /// Further local/regional names for this species, flattened from the API's `localNames` array.
    /// Empty (never a decoding failure) when the API omits or empties the array.
    let localNames: [SpeciesName]
    /// Whether this species is currently active in the reference catalogue. Defaults to `true`
    /// when the API omits the field, matching its own observed default.
    let isActive: Bool
    /// Live weight above minimum size retained (kg), as entered. Empty until captured.
    let weightAboveMinimumKg: String
    /// Live weight below minimum size retained (kg), as entered, when the user revealed the field.
    let weightBelowMinimumKg: String?
    /// Live weight legally discarded (kg), as entered, when the user revealed the field.
    let weightLegallyDiscardedKg: String?
    /// The numeric precision this species' weights must be recorded to (see
    /// `SpeciesWeightValidation`). The reference-data API does not supply this per species (some
    /// species are recorded in whole kg); defaults to `.oneDecimalPlace` so no species is blocked
    /// from being recorded while that data is not yet available.
    var weightPrecision: WeightPrecision = .oneDecimalPlace

    init(
        id: String,
        name: String,
        faoCode: String? = nil,
        scientificName: String? = nil,
        commonNames: [SpeciesName] = [],
        localNames: [SpeciesName] = [],
        isActive: Bool = true,
        weightAboveMinimumKg: String = "",
        weightBelowMinimumKg: String? = nil,
        weightLegallyDiscardedKg: String? = nil,
        weightPrecision: WeightPrecision = .oneDecimalPlace
    ) {
        self.id = id
        self.name = name
        self.faoCode = faoCode
        self.scientificName = scientificName
        self.commonNames = commonNames
        self.localNames = localNames
        self.isActive = isActive
        self.weightAboveMinimumKg = weightAboveMinimumKg
        self.weightBelowMinimumKg = weightBelowMinimumKg
        self.weightLegallyDiscardedKg = weightLegallyDiscardedKg
        self.weightPrecision = weightPrecision
    }

    /// Convenience for the current stub, where the name is also the stable identifier.
    init(name: String) {
        self.init(id: name, name: name)
    }

    /// Maps the wire DTO into the domain type, flattening `commonNames`/`localNames` and deriving
    /// `name` (the API has no top-level display name): the first GBR common name when present,
    /// falling back to the first common name of any country, then `scientificName`, then `id`.
    init(dto: SpeciesDTO) {
        let commonNames = (dto.commonNames ?? []).map(SpeciesName.init(dto:))
        let localNames = (dto.localNames ?? []).map(SpeciesName.init(dto:))
        self.init(
            id: dto.id,
            name: Self.derivedName(
                id: dto.id,
                faoCode: dto.faoCode,
                scientificName: dto.scientificName,
                commonNames: commonNames
            ),
            faoCode: dto.faoCode,
            scientificName: dto.scientificName,
            commonNames: commonNames,
            localNames: localNames,
            isActive: dto.active ?? true
        )
    }

    /// Derives a single display `name` of the form `"Common name (FAOCODE)"` from the API's
    /// `commonNames` array, preferring a GBR entry, falling back to the first entry of any
    /// country, then `scientificName`, then `id` — so every species always has a non-empty name.
    private static func derivedName(
        id: String,
        faoCode: String?,
        scientificName: String?,
        commonNames: [SpeciesName]
    ) -> String {
        let commonName = commonNames.first { $0.countryCode == "GBR" }?.name ?? commonNames.first?.name
        let base = commonName ?? scientificName ?? id
        if let faoCode, !faoCode.isEmpty {
            return "\(base) (\(faoCode))"
        }
        return base
    }

    /// Returns a copy of this species with the given captured weights attached.
    func withWeights(
        above: String,
        below: String?,
        discarded: String?
    ) -> SpeciesOption {
        SpeciesOption(
            id: id,
            name: name,
            faoCode: faoCode,
            scientificName: scientificName,
            commonNames: commonNames,
            localNames: localNames,
            isActive: isActive,
            weightAboveMinimumKg: above,
            weightBelowMinimumKg: below,
            weightLegallyDiscardedKg: discarded,
            weightPrecision: weightPrecision
        )
    }
}

/// A single localised/common name for a species, flattened from the API's `commonNames`/
/// `localNames` arrays (see `SpeciesNameDTO`).
nonisolated struct SpeciesName: Hashable, Sendable, Codable {
    let id: String?
    let countryCode: String?
    let name: String

    init(id: String? = nil, countryCode: String? = nil, name: String) {
        self.id = id
        self.countryCode = countryCode
        self.name = name
    }

    init(dto: SpeciesNameDTO) {
        self.id = dto.id
        self.countryCode = dto.countryCode
        self.name = dto.name
    }
}

/// The numeric precision a species' recorded weight must conform to (see `SpeciesWeightValidation`).
nonisolated enum WeightPrecision: String, Hashable, Sendable, Codable {
    /// Up to 1 decimal place (e.g. "12.5") — the default for most species.
    case oneDecimalPlace
    /// A whole number only (e.g. "12") — species recorded without fractional kg.
    case wholeNumber
}

extension SpeciesOption {
    /// Atlantic cod — the worked example from the design mocks.
    static let atlanticCod = SpeciesOption(name: "Atlantic cod (COD)")
}
