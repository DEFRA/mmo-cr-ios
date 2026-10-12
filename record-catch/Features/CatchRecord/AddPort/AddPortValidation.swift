import Foundation

/// Pure, static validation for the Add-port screen.
///
/// Two rules, in GOV.UK priority order (missing → fails another rule):
/// 1. The search field must not be left blank ("Enter the port you want to add").
/// 2. Once typed, a port must be picked from the results list ("Select a port from the list").
///
/// Mirrors `AddSpeciesValidation`. GOV.UK's "Be specific" guidance warns against reusing one
/// generic message for every failure state, so the blank case gets its own instruction rather
/// than telling a user who has typed nothing to "select from the list".
nonisolated enum AddPortValidation {

    /// Returns the current validation message, or `nil` when a valid port is selected.
    ///
    /// Checks the selection first, rather than the query text: in normal use
    /// `SearchDropdownField` keeps `query` and the selection in lock-step (choosing a result sets
    /// both together), but a valid selection must never be second-guessed by a merely-stale query
    /// value — e.g. a caller (or test) that sets the selection directly.
    static func message(query: String, selectedPort: PortOption?) -> ValidationMessage? {
        guard selectedPort == nil else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ValidationMessage("catchRecord.addPort.validation.enter")
        }
        return ValidationMessage("catchRecord.addPort.validation.none")
    }
}

