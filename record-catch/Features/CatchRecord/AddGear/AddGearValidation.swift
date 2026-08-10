import Foundation

/// Pure, static validation for the Add-gear screen.
nonisolated enum AddGearValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when a gear has been selected.
    static func errorKey(for selection: GearOption?) -> String? {
        selection == nil ? "catchRecord.addGear.validation.none" : nil
    }
}
