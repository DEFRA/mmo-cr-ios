import Foundation

/// Pure, static validation for the "select favourite port" screen (departure and return).
nonisolated enum SelectPortValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when a port is selected.
    static func errorKey(for selection: String?, phase: SelectPortPhase) -> String? {
        selection == nil ? phase.validationKey : nil
    }
}
