import Foundation

/// Pure, static validation for the "What gear did you use?" (select gear) screen.
///
/// Kept out of the view model/view so the rule is trivially unit-testable with no view host.
nonisolated enum SelectGearValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when at least one gear is
    /// selected.
    static func errorKey(for selection: Set<String>) -> String? {
        selection.isEmpty ? "catchRecord.selectGear.validation.none" : nil
    }
}
