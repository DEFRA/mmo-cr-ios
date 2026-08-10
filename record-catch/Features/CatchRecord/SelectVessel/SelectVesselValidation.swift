import Foundation

/// Pure, static validation for the Select vessel screen.
enum SelectVesselValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when `selection` is valid.
    static func errorKey(for selection: String?) -> String? {
        selection == nil ? "catchRecord.selectVessel.validation.none" : nil
    }
}
