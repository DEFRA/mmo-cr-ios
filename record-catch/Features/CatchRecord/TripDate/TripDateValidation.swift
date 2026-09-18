import Foundation

/// The outcome of validating a trip date: the message to show, and which field(s) it targets.
///
/// An empty `parts` set means "highlight the date as a whole" (GOV.UK guidance: highlight
/// individual fields only when the error is specific to them — e.g. a missing day — and highlight
/// the whole group for errors that describe the date overall, such as "must be on or after…").
nonisolated struct TripDateValidationResult: Equatable {
    let message: ValidationMessage
    let parts: Set<DateEntryField.Part>

    init(_ message: ValidationMessage, parts: Set<DateEntryField.Part> = []) {
        self.message = message
        self.parts = parts
    }
}

/// Pure, static validation for the trip-date screen (departure and return).
///
/// Kept out of the view model/view so the rule is trivially unit-testable with no view host.
/// Rules are evaluated in GOV.UK's stated priority order (missing/incomplete → cannot be correct →
/// fails another rule):
///
/// **Departure**: day missing → month missing → year missing → not a real date → before the
/// service's earliest supported trip date → in the future.
///
/// **Return**: day missing → month missing → year missing → not a real date → in the future →
/// before the recorded departure date.
nonisolated enum TripDateValidation {

    private static func isBlank(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns the current validation result for `value`, or `nil` when it is fully valid for
    /// `phase`. `locale` is only consulted to render the earliest-trip-date message (e.g. "24 July
    /// 2025" / "24 Gorffennaf 2025") — it never changes *whether* the value is considered valid.
    static func result(
        for value: DateEntryValue,
        phase: TripDatePhase,
        departureDate: Date?,
        now: Date,
        locale: Locale,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> TripDateValidationResult? {
        let missingKeys = phase.missingFieldKeys

        if isBlank(value.day) {
            return TripDateValidationResult(ValidationMessage(missingKeys.day), parts: [.day])
        }
        if isBlank(value.month) {
            return TripDateValidationResult(ValidationMessage(missingKeys.month), parts: [.month])
        }
        if isBlank(value.year) {
            return TripDateValidationResult(ValidationMessage(missingKeys.year), parts: [.year])
        }

        guard let date = DateEntryField.parsedDate(from: value) else {
            return TripDateValidationResult(ValidationMessage(phase.formatKey))
        }

        switch phase {
        case .departure:
            let minimumDate = CatchRecordDateRules.earliestTripDate
            if calendar.startOfDay(for: date) < calendar.startOfDay(for: minimumDate) {
                let formatted = CatchRecordDateRules.longDateString(minimumDate, locale: locale)
                return TripDateValidationResult(
                    ValidationMessage("catchRecord.tripDate.departure.validation.minimumDate", arguments: [formatted])
                )
            }
            guard CatchRecordDateRules.isTodayOrInThePast(date, now: now, calendar: calendar) else {
                return TripDateValidationResult(ValidationMessage("catchRecord.tripDate.departure.validation.future"))
            }
            return nil

        case .return:
            guard CatchRecordDateRules.isTodayOrInThePast(date, now: now, calendar: calendar) else {
                return TripDateValidationResult(ValidationMessage("catchRecord.tripDate.return.validation.future"))
            }
            if let departureDate, calendar.startOfDay(for: date) < calendar.startOfDay(for: departureDate) {
                return TripDateValidationResult(
                    ValidationMessage("catchRecord.tripDate.return.validation.beforeDeparture")
                )
            }
            return nil
        }
    }
}

private extension TripDatePhase {
    /// The three "field missing" String Catalog keys for this phase.
    struct MissingFieldKeys {
        let day: String
        let month: String
        let year: String
    }

    var missingFieldKeys: MissingFieldKeys {
        switch self {
        case .departure:
            return MissingFieldKeys(
                day: "catchRecord.tripDate.departure.validation.day",
                month: "catchRecord.tripDate.departure.validation.month",
                year: "catchRecord.tripDate.departure.validation.year"
            )
        case .return:
            return MissingFieldKeys(
                day: "catchRecord.tripDate.return.validation.day",
                month: "catchRecord.tripDate.return.validation.month",
                year: "catchRecord.tripDate.return.validation.year"
            )
        }
    }

    /// The "not a real/parseable date" String Catalog key for this phase (the two phases use
    /// slightly different wording — see plan Q6).
    var formatKey: String {
        switch self {
        case .departure: return "catchRecord.tripDate.departure.validation.format"
        case .return: return "catchRecord.tripDate.return.validation.format"
        }
    }
}
