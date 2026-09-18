import SwiftUI

/// The three parts of a day/month/year date entry.
struct DateEntryValue: Equatable {
    var day: String = ""
    var month: String = ""
    var year: String = ""

    init(day: String = "", month: String = "", year: String = "") {
        self.day = day
        self.month = month
        self.year = year
    }

    /// Builds the field values from an existing `Date` — used to pre-fill a resumed draft's
    /// already-captured date (see ADR-0015 decision #1, `TripDateViewModel`).
    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        self.day = components.day.map(String.init) ?? ""
        self.month = components.month.map(String.init) ?? ""
        self.year = components.year.map(String.init) ?? ""
    }

    /// Whether every part is blank.
    var isEmpty: Bool { day.isEmpty && month.isEmpty && year.isEmpty }
}

/// A GOV.UK-style day/month/year date input with inline validation.
///
/// Follows the GOV.UK Design System *Date input* pattern: three separate numeric
/// fields grouped together, described by the screen's question, with no auto-tab
/// between fields. Copy (field labels + error) is localised via `AppLanguageStore`
/// so it renders correctly in English and Welsh (WCAG 3.1.2 Language of Parts),
/// and the group is exposed to VoiceOver as a single container labelled by the
/// screen heading (WCAG 1.3.1 / 3.3.2).
///
/// Purely presentational for validation: the caller (e.g. `TripDateViewModel` via
/// `TripDateValidation`) decides *what* the current error is and *which* field(s) it belongs to;
/// this view only renders that decision, following GOV.UK's guidance to highlight just the
/// offending field(s) when known, or the whole group otherwise.
struct DateEntryField: View {
    /// Which of the three fields a validation error applies to. GOV.UK: highlight only the field
    /// that has the error when it's known to be a specific one; otherwise (e.g. "not a real date",
    /// "must be on or after…") highlight the date as a whole.
    enum Part: Hashable {
        case day
        case month
        case year
    }

    let title: String
    let hint: String
    @Binding var value: DateEntryValue
    var didAttemptSubmit: Bool = false
    /// The current validation message, already localised — `nil` when the value is valid. The
    /// caller (`TripDateValidation`) computes this, so `DateEntryField` has no validation logic of
    /// its own beyond `parsedDate(from:)`.
    var errorMessage: String?
    /// Which specific field(s) `errorMessage` applies to. Empty means "highlight the whole group"
    /// (used for whole-date errors such as "must be on or after 24 July 2025").
    var errorParts: Set<Part> = []
    /// Accessibility identifier prefix; the inline error uses `<prefix>.error`.
    var accessibilityIdentifierPrefix: String = "DateEntry"

    @Environment(AppLanguageStore.self) private var languageStore
    @FocusState private var focusedPart: Part?
    @State private var hasBlurred = false

    private var shouldShowError: Bool {
        (didAttemptSubmit || hasBlurred) && errorMessage != nil
    }

    /// Whether a specific field should be individually highlighted: only when the error targets
    /// specific field(s) — an empty `errorParts` highlights every field via `highlightsWholeGroup`.
    private func isPartHighlighted(_ part: Part) -> Bool {
        shouldShowError && (errorParts.isEmpty || errorParts.contains(part))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)

            ParagraphText(text: hint, isHint: true)

            if shouldShowError, let errorMessage {
                InlineErrorText(
                    message: errorMessage,
                    accessibilityIdentifier: "\(accessibilityIdentifierPrefix).error"
                )
            }

            HStack(alignment: .top, spacing: AppSpacing.small) {
                field(
                    label: languageStore.localized("component.dateEntry.day"),
                    text: $value.day,
                    width: AppControlSize.dateFieldShortWidth,
                    part: .day
                )
                field(
                    label: languageStore.localized("component.dateEntry.month"),
                    text: $value.month,
                    width: AppControlSize.dateFieldShortWidth,
                    part: .month
                )
                field(
                    label: languageStore.localized("component.dateEntry.year"),
                    text: $value.year,
                    width: AppControlSize.dateFieldYearWidth,
                    part: .year
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .onChange(of: focusedPart) { _, newValue in
            if newValue == nil {
                hasBlurred = true
            }
        }
    }

    private func field(label: String, text: Binding<String>, width: CGFloat, part: Part) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(label)
                .font(AppTypography.fieldLabel)
                .foregroundStyle(AppColors.textPrimary)

            TextField("", text: text)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: width, height: AppControlSize.dateFieldHeight)
                .padding(.horizontal, AppSpacing.small)
                .background(AppColors.background)
                .overlay(
                    Rectangle()
                        .stroke(isPartHighlighted(part) ? AppColors.errorRed : AppColors.borderDefault, lineWidth: 1)
                )
                .focused($focusedPart, equals: part)
                .onChange(of: text.wrappedValue) { _, newValue in
                    text.wrappedValue = String(newValue.filter(\.isNumber).prefix(part == .year ? 4 : 2))
                }
                .accessibilityLabel(label)
        }
    }

    /// Parses a real calendar date from `value`, or `nil` when it is not one.
    ///
    /// Accepts 1 or 2 digit day/month (e.g. "3" or "03"), matching the GOV.UK date-input pattern's
    /// accepted example format ("31 3 2019") and the values `DateEntryValue(date:)` itself produces
    /// when pre-filling from an existing `Date` (which are not zero-padded). The year must be
    /// exactly 4 digits.
    static func parsedDate(from value: DateEntryValue) -> Date? {
        guard
            let day = Int(value.day), (1...2).contains(value.day.count),
            let month = Int(value.month), (1...2).contains(value.month.count),
            let year = Int(value.year), value.year.count == 4
        else {
            return nil
        }

        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year

        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else {
            return nil
        }

        // Reject normalized dates like 31/02 becoming 02/03.
        let resolved = calendar.dateComponents([.day, .month, .year], from: date)
        guard resolved.day == day, resolved.month == month, resolved.year == year else {
            return nil
        }

        return date
    }
}

#Preview {
    @Previewable @State var value = DateEntryValue()

    return DateEntryField(
        title: "When did you leave for your trip?",
        hint: "Enter the date you departed. For example, 31 3 2019",
        value: $value,
        didAttemptSubmit: true,
        errorMessage: "Enter the day you left for your trip",
        errorParts: [.day],
        accessibilityIdentifierPrefix: "Preview.date"
    )
    .padding()
    .environment(AppLanguageStore.preview)
}
