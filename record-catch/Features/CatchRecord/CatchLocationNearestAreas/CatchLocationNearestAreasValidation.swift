import Foundation

/// Pure, static validation for the "Select the statistical sub area…" nearest-areas screen,
/// reached from `CatchLocationView`'s "Other" button (see
/// `CatchLocationNearestAreasViewModel`).
///
/// Mirrors `CatchLocationValidation`: a single rule, since every row (including "Other") is
/// represented as one `RadioGroup` selection — picking "Other" is itself a valid selection that
/// routes to the manual entry screen, so the only failure is nothing chosen at all.
nonisolated enum CatchLocationNearestAreasValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when an option (an area or
    /// "Other") has been selected.
    static func errorKey(for selection: String?) -> String? {
        let hasSelection = (selection?.isEmpty == false)
        return hasSelection ? nil : "catchRecord.nearestAreas.validation.none"
    }
}
