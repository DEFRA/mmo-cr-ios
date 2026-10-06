import Foundation

/// Pure, static validation for the Add-gear screen. Mirrors `AddPortValidation` — see there for
/// why the blank and typed-but-unselected states get different copy.
nonisolated enum AddGearValidation {

    /// Returns the current validation message, or `nil` when a valid gear is selected.
    ///
    /// Checks the selection first — see `AddPortValidation.message` for why.
    static func message(query: String, selectedGear: GearOption?) -> ValidationMessage? {
        guard selectedGear == nil else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ValidationMessage("catchRecord.addGear.validation.enter")
        }
        return ValidationMessage("catchRecord.addGear.validation.none")
    }
}

