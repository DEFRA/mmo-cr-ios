import Foundation

/// Pure, static validation for the "Which species did you catch with `<gear>`?" screen.
///
/// Two levels of rule, in GOV.UK priority order:
/// 1. At least one species must be ticked ("Select at least one species").
/// 2. For each ticked species, the mandatory "above minimum" weight must be present and valid; the
///    optional "below minimum"/"legally discarded" weights, when revealed, must be valid if
///    non-blank (see plan Q2 — only the above-minimum weight is required).
nonisolated enum RecordSpeciesWeightsValidation {

    /// Which weight field on a species row a validation message belongs to, so the view can
    /// render each error against its own `TextInputField` (see `TextInputFieldTests`/GOV.UK
    /// per-field highlighting guidance).
    enum WeightField: Hashable, Sendable {
        case above
        case below
        case discarded
    }

    /// Returns the "select at least one species" message, or `nil` when at least one is ticked.
    static func selectionErrorMessage(selection: Set<String>) -> ValidationMessage? {
        selection.isEmpty ? ValidationMessage("catchRecord.species.record.validation.none") : nil
    }

    /// Returns every weight-field error for the ticked species, keyed by `(speciesID, field)`.
    ///
    /// - Parameters:
    ///   - selection: ids of ticked species.
    ///   - species: the full favourites list (to resolve names/precision).
    ///   - entries: the raw per-species field text and which optional fields are revealed — a
    ///     hidden/removed field is not validated even if it still holds stale text.
    static func weightErrorMessages(
        selection: Set<String>,
        species: [SpeciesOption],
        entries: SpeciesWeightEntries
    ) -> [SpeciesFieldKey: ValidationMessage] {
        var errors: [SpeciesFieldKey: ValidationMessage] = [:]
        for option in species where selection.contains(option.id) {
            if let message = SpeciesWeightValidation.requiredErrorMessage(
                for: entries.above[option.id] ?? "",
                speciesName: option.name,
                precision: option.weightPrecision,
                enterKey: "catchRecord.species.weight.validation.enter"
            ) {
                errors[SpeciesFieldKey(speciesID: option.id, field: .above)] = message
            }
            if entries.belowRevealed.contains(option.id),
               let message = SpeciesWeightValidation.optionalErrorMessage(
                   for: entries.below[option.id] ?? "",
                   speciesName: option.name,
                   precision: option.weightPrecision
               ) {
                errors[SpeciesFieldKey(speciesID: option.id, field: .below)] = message
            }
            if entries.discardedRevealed.contains(option.id),
               let message = SpeciesWeightValidation.optionalErrorMessage(
                   for: entries.discarded[option.id] ?? "",
                   speciesName: option.name,
                   precision: option.weightPrecision
               ) {
                errors[SpeciesFieldKey(speciesID: option.id, field: .discarded)] = message
            }
        }
        return errors
    }
}

/// The raw per-species weight field text and which optional fields are currently revealed,
/// bundled together so `weightErrorMessages(selection:species:entries:)` stays within the
/// project's function-parameter-count limit.
nonisolated struct SpeciesWeightEntries {
    let above: [String: String]
    let below: [String: String]
    let discarded: [String: String]
    let belowRevealed: Set<String>
    let discardedRevealed: Set<String>
}

/// Composite key identifying a single weight field on a single species row.
nonisolated struct SpeciesFieldKey: Hashable, Sendable {
    let speciesID: String
    let field: RecordSpeciesWeightsValidation.WeightField
}
