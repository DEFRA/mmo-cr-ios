import Foundation

/// Pure, static validation for the "Which species did you catch with `<gear>`?" screen.
///
/// Two levels of rule, in GOV.UK priority order:
/// 1. At least one species must be ticked ("Select at least one species").
/// 2. For each ticked species, the mandatory "above minimum" weight must be present and valid; the
///    optional "below minimum"/"legally discarded" weights, when revealed, must be valid if
///    non-blank (see plan Q2 — only the above-minimum weight is required); and, when both the
///    "above minimum" (retained) and "legally discarded" weights are present and individually
///    valid, the retained weight must be strictly higher than the discarded weight (AC7/TC-12 —
///    legally discarding at least as much as was retained does not make sense). The comparison
///    error is only raised once both fields are otherwise error-free, and is attached to the
///    "legally discarded" field.
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
            let aboveRaw = entries.above[option.id] ?? ""
            if let message = SpeciesWeightValidation.requiredErrorMessage(
                for: aboveRaw,
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
            let discardedKey = SpeciesFieldKey(speciesID: option.id, field: .discarded)
            let discardedRaw = entries.discarded[option.id] ?? ""
            if entries.discardedRevealed.contains(option.id),
               let message = SpeciesWeightValidation.optionalErrorMessage(
                   for: discardedRaw,
                   speciesName: option.name,
                   precision: option.weightPrecision
               ) {
                errors[discardedKey] = message
            } else if entries.discardedRevealed.contains(option.id),
                      errors[SpeciesFieldKey(speciesID: option.id, field: .above)] == nil,
                      let comparisonMessage = discardedExceedsRetainedMessage(
                          aboveRaw: aboveRaw,
                          discardedRaw: discardedRaw,
                          speciesName: option.name,
                          precision: option.weightPrecision
                      ) {
                errors[discardedKey] = comparisonMessage
            }
        }
        return errors
    }

    /// Returns the AC7/TC-12 "must be higher than" message when both the retained ("above
    /// minimum") and legally-discarded weights parse successfully and the discarded weight is
    /// greater than or equal to the retained weight, or `nil` otherwise (including when either
    /// field is blank — the comparison only applies once both are present).
    private static func discardedExceedsRetainedMessage(
        aboveRaw: String,
        discardedRaw: String,
        speciesName: String,
        precision: WeightPrecision
    ) -> ValidationMessage? {
        guard let above = SpeciesWeightValidation.parse(aboveRaw, precision: precision),
              let discarded = SpeciesWeightValidation.parse(discardedRaw, precision: precision),
              discarded >= above
        else { return nil }
        return ValidationMessage(
            "catchRecord.species.weight.validation.discardedExceedsRetained",
            arguments: [speciesName]
        )
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
