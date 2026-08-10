import Foundation

/// Pure, static validation for a single whole-number gear measurement field.
nonisolated enum GearMeasurementValidation {
    /// Parses a whole-number measurement from raw field text.
    ///
    /// Returns the parsed `Int` when the trimmed text is a valid non-negative whole number,
    /// otherwise `nil` (empty, non-numeric, negative or decimal values are invalid).
    static func parse(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    /// String Catalog key for the inline error, or `nil` when the text is a valid whole number.
    static func errorKey(for raw: String) -> String? {
        parse(raw) == nil ? "catchRecord.gear.measurement.validation.wholeNumber" : nil
    }
}
