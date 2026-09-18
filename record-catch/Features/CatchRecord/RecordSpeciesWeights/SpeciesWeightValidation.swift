import Foundation

/// Pure, static validation for a single species weight field (e.g. "weight above minimum size
/// retained"), shared by `RecordSpeciesWeightsViewModel` and `LandingStorageSpeciesViewModel`.
///
/// Mirrors `GearMeasurementValidation`'s pure-parse style. Three rules, in GOV.UK priority order
/// (missing → wrong format → fails another rule):
/// 1. Required fields must not be left blank (only the "above minimum" field is required — see
///    plan Q2; "below minimum" and "legally discarded" are optional and skipped entirely when blank).
/// 2. The entered value must match the species' `WeightPrecision` (a whole number, or a number with
///    up to 1 decimal place).
/// 3. The value must be greater than zero.
nonisolated enum SpeciesWeightValidation {

    /// Whether `raw` is present after trimming whitespace.
    private static func isBlank(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Parses a weight matching `precision`, or `nil` when the trimmed text is not a valid number
    /// at that precision (empty, non-numeric, more decimal places than allowed, or using a comma
    /// decimal separator, which is rejected rather than silently reinterpreted).
    static func parse(_ raw: String, precision: WeightPrecision) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Reject anything but digits and a single "." decimal point up front, so "1,5" (a likely
        // European decimal-comma entry) is treated as a format error rather than silently parsed.
        guard trimmed.allSatisfy({ $0.isNumber || $0 == "." }) else { return nil }
        switch precision {
        case .wholeNumber:
            guard !trimmed.contains("."), let value = Double(trimmed) else { return nil }
            return value
        case .oneDecimalPlace:
            let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count <= 2, let value = Double(trimmed) else { return nil }
            if parts.count == 2, parts[1].count > 1 { return nil }
            return value
        }
    }

    /// Returns the `ValidationMessage` for a required field (blank is an error), or `nil` when
    /// `raw` is valid for `precision` and greater than zero.
    ///
    /// - Parameters:
    ///   - raw: the entered text.
    ///   - speciesName: interpolated into the format/precision/zero messages (e.g. "Atlantic cod
    ///     (COD)").
    ///   - precision: the species' required numeric precision.
    ///   - enterKey: the String Catalog key for the "field left blank" message — differs between
    ///     the record-weights screen and the landing-storage-species screen because their field
    ///     labels differ.
    static func requiredErrorMessage(
        for raw: String,
        speciesName: String,
        precision: WeightPrecision,
        enterKey: String
    ) -> ValidationMessage? {
        if isBlank(raw) {
            return ValidationMessage(enterKey, arguments: [speciesName])
        }
        return formatErrorMessage(for: raw, speciesName: speciesName, precision: precision)
    }

    /// Returns the `ValidationMessage` for an **optional** field (blank is valid — the field is
    /// simply not recorded), or `nil` when `raw` is valid for `precision` and greater than zero.
    static func optionalErrorMessage(
        for raw: String,
        speciesName: String,
        precision: WeightPrecision
    ) -> ValidationMessage? {
        guard !isBlank(raw) else { return nil }
        return formatErrorMessage(for: raw, speciesName: speciesName, precision: precision)
    }

    /// Format/range checks shared by the required and optional variants once blankness has been
    /// handled by the caller.
    private static func formatErrorMessage(
        for raw: String,
        speciesName: String,
        precision: WeightPrecision
    ) -> ValidationMessage? {
        guard let value = parse(raw, precision: precision) else {
            let key = precision == .wholeNumber
                ? "catchRecord.species.weight.validation.wholeNumber"
                : "catchRecord.species.weight.validation.decimalPlace"
            return ValidationMessage(key, arguments: [speciesName])
        }
        guard value > 0 else {
            return ValidationMessage("catchRecord.species.weight.validation.greaterThanZero", arguments: [speciesName])
        }
        return nil
    }
}
