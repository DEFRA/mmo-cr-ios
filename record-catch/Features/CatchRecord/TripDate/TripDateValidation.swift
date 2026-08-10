import Foundation

/// Pure, static validation for the trip-date screen (departure and return).
///
/// Kept out of the view model/view so the rule is trivially unit-testable with no view host.
/// Cross-field validation (return on or after departure) is deliberately out of scope for this
/// UI-only phase; this validator only checks that the entered value is a real calendar date.
enum TripDateValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when `value` is a real date.
    static func errorKey(for value: DateEntryValue) -> String? {
        DateEntryField.parsedDate(from: value) == nil ? "catchRecord.tripDate.validation.none" : nil
    }
}
