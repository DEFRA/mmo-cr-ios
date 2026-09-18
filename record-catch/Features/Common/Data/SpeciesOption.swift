import Foundation

/// A species the user can search for, save as a favourite, and record weights against.
///
/// API-shaped value type mirroring `GearOption`/`PortOption` (see ADR-0004). The species list is a
/// future API; stubbed for now. The three optional weights capture the user-entered live weights in
/// kilograms for this species: `weightAboveMinimumKg` is always available once a species is recorded,
/// while `weightBelowMinimumKg` and `weightLegallyDiscardedKg` are optional extras the user can reveal.
/// Weights are held as the raw entered strings for this phase — numeric validation is applied by
/// `SpeciesWeightValidation`, keyed off `weightPrecision`.
///
/// Explicitly `nonisolated` so it can be constructed and read from any actor context (the stubbed
/// providers run off the main actor); a plain `Sendable` value type has no isolation needs.
nonisolated struct SpeciesOption: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    /// Live weight above minimum size retained (kg), as entered. Empty until captured.
    let weightAboveMinimumKg: String
    /// Live weight below minimum size retained (kg), as entered, when the user revealed the field.
    let weightBelowMinimumKg: String?
    /// Live weight legally discarded (kg), as entered, when the user revealed the field.
    let weightLegallyDiscardedKg: String?
    /// The numeric precision this species' weights must be recorded to (see
    /// `SpeciesWeightValidation`). A future Species API supplies this per species (some species are
    /// recorded in whole kg); defaults to `.oneDecimalPlace` so no species is blocked from being
    /// recorded while that data is not yet available (see plan Q1).
    var weightPrecision: WeightPrecision = .oneDecimalPlace

    init(
        id: String,
        name: String,
        weightAboveMinimumKg: String = "",
        weightBelowMinimumKg: String? = nil,
        weightLegallyDiscardedKg: String? = nil,
        weightPrecision: WeightPrecision = .oneDecimalPlace
    ) {
        self.id = id
        self.name = name
        self.weightAboveMinimumKg = weightAboveMinimumKg
        self.weightBelowMinimumKg = weightBelowMinimumKg
        self.weightLegallyDiscardedKg = weightLegallyDiscardedKg
        self.weightPrecision = weightPrecision
    }

    /// Convenience for the current stub, where the name is also the stable identifier.
    init(name: String) {
        self.init(id: name, name: name)
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
            weightAboveMinimumKg: above,
            weightBelowMinimumKg: below,
            weightLegallyDiscardedKg: discarded,
            weightPrecision: weightPrecision
        )
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
