import SwiftUI

/// The three parts of a day/month/year date entry.
struct DateEntryValue: Equatable {
    var day: String = ""
    var month: String = ""
    var year: String = ""
}

/// A GOV.UK-style day/month/year date input with inline validation.
///
/// Follows the GOV.UK Design System *Date input* pattern: three separate numeric
/// fields grouped together, described by the screen's question, with no auto-tab
/// between fields. Copy (field labels + error) is localised via `AppLanguageStore`
/// so it renders correctly in English and Welsh (WCAG 3.1.2 Language of Parts),
/// and the group is exposed to VoiceOver as a single container labelled by the
/// screen heading (WCAG 1.3.1 / 3.3.2).
struct DateEntryField: View {
    let title: String
    let hint: String
    @Binding var value: DateEntryValue
    var didAttemptSubmit: Bool = false
    /// String Catalog key for the inline error shown when the date is not real.
    var errorKey: String = "component.dateEntry.validation.none"
    /// Accessibility identifier prefix; the inline error uses `<prefix>.error`.
    var accessibilityIdentifierPrefix: String = "DateEntry"

    @Environment(AppLanguageStore.self) private var languageStore
    @FocusState private var focusedPart: Part?
    @State private var hasBlurred = false

    private enum Part {
        case day
        case month
        case year
    }

    private var shouldShowError: Bool {
        (didAttemptSubmit || hasBlurred) && !isValidDate
    }

    private var isValidDate: Bool {
        Self.parsedDate(from: value) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)

            ParagraphText(text: hint, isHint: true)

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

            if shouldShowError {
                errorRow
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

    private var errorRow: some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            LocalizedText(errorKey)
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized(errorKey))"
        )
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).error")
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
                        .stroke(shouldShowError ? AppColors.errorRed : AppColors.borderDefault, lineWidth: 1)
                )
                .focused($focusedPart, equals: part)
                .onChange(of: text.wrappedValue) { _, newValue in
                    text.wrappedValue = String(newValue.filter(\.isNumber).prefix(part == .year ? 4 : 2))
                }
                .accessibilityLabel(label)
        }
    }

    static func parsedDate(from value: DateEntryValue) -> Date? {
        guard
            let day = Int(value.day),
            let month = Int(value.month),
            let year = Int(value.year),
            value.day.count == 2,
            value.month.count == 2,
            value.year.count == 4
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
        hint: "Enter the date you departed. For example, 31/03/2020",
        value: $value,
        didAttemptSubmit: true,
        accessibilityIdentifierPrefix: "Preview.date"
    )
    .padding()
    .environment(AppLanguageStore.preview)
}
