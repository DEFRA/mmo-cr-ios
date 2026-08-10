import Foundation

/// Pure, static validation for the "Where was most of your catch caught using <gear>?" screen.
///
/// Kept out of the view model/view so the rule is trivially unit-testable with no view host,
/// mirroring `SelectGearValidation`.
nonisolated enum CatchLocationValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when a statistical area has
    /// been selected on the map.
    static func errorKey(for selectedArea: String?) -> String? {
        let hasSelection = (selectedArea?.isEmpty == false)
        return hasSelection ? nil : "catchRecord.catchLocation.validation.none"
    }
}
