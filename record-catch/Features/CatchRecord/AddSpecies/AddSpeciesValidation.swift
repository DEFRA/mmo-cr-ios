import Foundation

/// Pure, static validation for the Add-species screen.
///
/// Two rules, in GOV.UK priority order (missing → fails another rule):
/// 1. The search field must not be left blank ("Enter the species…").
/// 2. Once typed, a species must be picked from the results list ("Select a species…" /
///    "Select the species…").
///
/// Copy differs by `AddSpeciesContext` (see plan Q3) — mirrors `SelectPortValidation`'s
/// phase-keyed messages.
nonisolated enum AddSpeciesValidation {

    /// Returns the current validation message, or `nil` when a valid species is selected.
    static func message(
        query: String,
        selectedSpecies: SpeciesOption?,
        context: AddSpeciesContext
    ) -> ValidationMessage? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ValidationMessage(context.enterKey)
        }
        guard selectedSpecies != nil else {
            return ValidationMessage(context.selectKey)
        }
        return nil
    }
}

private extension AddSpeciesContext {
    var enterKey: String {
        switch self {
        case .firstTime: return "catchRecord.species.add.validation.enter"
        case .addAnother: return "catchRecord.species.trip.validation.enter"
        }
    }

    var selectKey: String {
        switch self {
        case .firstTime: return "catchRecord.species.add.validation.select"
        case .addAnother: return "catchRecord.species.trip.validation.select"
        }
    }
}
