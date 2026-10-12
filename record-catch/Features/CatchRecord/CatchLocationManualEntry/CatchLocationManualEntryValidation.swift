import Foundation

/// Pure, static validation for the manual "Enter the statistical sub area…" type-to-search screen.
///
/// Deliberately separate from `CatchLocationValidation`: the *map* screen has a single rule and no
/// search field, so its one message ("Select a statistical subrectangle") stays unchanged. This
/// screen is a type-ahead with two distinct failure states, and uses this screen's own wording
/// ("statistical sub area", matching its heading).
nonisolated enum CatchLocationManualEntryValidation {

    /// Returns the current validation message, or `nil` when a valid sub area is selected.
    ///
    /// Checks the selection first — see `AddPortValidation.message` for why.
    static func message(query: String, selectedCode: String?) -> ValidationMessage? {
        if let selectedCode, !selectedCode.isEmpty { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ValidationMessage("catchRecord.manualEntry.validation.enter")
        }
        return ValidationMessage("catchRecord.manualEntry.validation.select")
    }
}
