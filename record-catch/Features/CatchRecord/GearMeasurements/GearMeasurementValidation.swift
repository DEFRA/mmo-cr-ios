import Foundation

/// Pure, static validation for a single whole-number gear measurement field (e.g. mesh size, or a
/// per-trip variable measurement such as the number of times the gear was shot).
///
/// Two rules, in GOV.UK priority order (wrong format → fails another rule), mirroring
/// `SpeciesWeightValidation`:
/// 1. The entered value must be a whole number (empty, non-numeric, negative or decimal values are
///    invalid).
/// 2. The value must be greater than zero — a measurement of 0 is never physically possible (a mesh
///    size of 0mm, or gear shot 0 times, means there is nothing to record).
nonisolated enum GearMeasurementValidation {

    /// Parses a whole number from raw field text without enforcing positivity, for internal use by
    /// `parse(_:)` and `errorKey(for:)` so the format check itself is not duplicated.
    private static func parsedInt(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    /// Parses a whole-number measurement from raw field text.
    ///
    /// Returns the parsed `Int` when the trimmed text is a valid whole number greater than zero,
    /// otherwise `nil` (empty, non-numeric, negative, decimal or zero values are invalid).
    static func parse(_ raw: String) -> Int? {
        guard let value = parsedInt(raw), value > 0 else { return nil }
        return value
    }

    /// String Catalog key for the inline error, or `nil` when the text is a valid whole number
    /// greater than zero.
    static func errorKey(for raw: String) -> String? {
        guard let value = parsedInt(raw) else {
            return "catchRecord.gear.measurement.validation.wholeNumber"
        }
        guard value > 0 else {
            return "catchRecord.gear.measurement.validation.greaterThanZero"
        }
        return nil
    }
}
