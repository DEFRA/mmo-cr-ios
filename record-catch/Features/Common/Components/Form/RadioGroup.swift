import SwiftUI

/// A single option within a `RadioGroup`.
struct RadioGroupOption: Identifiable, Hashable {
    /// Stable identifier used for selection and `ForEach` identity (not shown to the user).
    let id: String
    /// Already-localised display title.
    let title: String
    /// Accessibility identifier for the rendered `RadioOption`.
    let accessibilityIdentifier: String
}

/// A single-select group of `RadioOption`s with an optional inline validation error.
///
/// Wraps the shared `RadioOption` component so screens compose a whole question (options +
/// selection + error) from one call site, matching the GOV.UK Design System Radios pattern
/// (grouped options, one visible error, error announced to assistive technology). Only one
/// option can be selected at a time via the shared `selectedID` binding.
struct RadioGroup: View {
    let options: [RadioGroupOption]
    @Binding var selectedID: String?
    /// String Catalog key for the inline error message; `nil` hides the error and border.
    var errorKey: String?
    /// Accessibility identifier for the group container.
    let groupAccessibilityIdentifier: String
    /// Accessibility identifier for the inline error, when shown.
    let errorAccessibilityIdentifier: String

    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            ForEach(options) { option in
                RadioOption(title: option.title, isSelected: selectedID == option.id) {
                    selectedID = option.id
                }
                .accessibilityIdentifier(option.accessibilityIdentifier)
            }

            if let errorKey {
                errorRow(key: errorKey)
            }
        }
        .padding(errorKey != nil ? AppSpacing.medium : 0)
        .overlay(errorOverlay)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(groupAccessibilityIdentifier)
    }

    @ViewBuilder
    private var errorOverlay: some View {
        if errorKey != nil {
            Rectangle().stroke(AppColors.errorRed, lineWidth: 2)
        }
    }

    private func errorRow(key: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            LocalizedText(key)
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized(key))"
        )
        .accessibilityIdentifier(errorAccessibilityIdentifier)
    }
}

#Preview {
    @Previewable @State var selection: String?
    return RadioGroup(
        options: [
            RadioGroupOption(id: "yes", title: "Yes", accessibilityIdentifier: "Preview.yes"),
            RadioGroupOption(id: "no", title: "No", accessibilityIdentifier: "Preview.no")
        ],
        selectedID: $selection,
        errorKey: "a11y.errorPrefix",
        groupAccessibilityIdentifier: "Preview.group",
        errorAccessibilityIdentifier: "Preview.error"
    )
    .padding()
    .environment(AppLanguageStore.preview)
}
