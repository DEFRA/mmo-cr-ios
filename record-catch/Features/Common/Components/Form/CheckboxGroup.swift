import SwiftUI

/// A single option within a `CheckboxGroup`.
struct CheckboxGroupOption: Identifiable, Hashable {
    /// Stable identifier used for selection and `ForEach` identity (not shown to the user).
    let id: String
    /// Already-localised display title.
    let title: String
    /// Optional already-localised secondary line (e.g. a measurement summary).
    let subtitle: String?
    /// Accessibility identifier for the rendered `CheckboxOption`.
    let accessibilityIdentifier: String

    init(id: String, title: String, subtitle: String? = nil, accessibilityIdentifier: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}

/// A multi-select group of `CheckboxOption`s with an optional inline validation error.
///
/// The checkbox sibling of `RadioGroup`: several options may be selected at once via the shared
/// `selectedIDs` set. Matches the GOV.UK Checkboxes pattern (grouped options, one visible error,
/// error announced to assistive technology).
struct CheckboxGroup: View {
    let options: [CheckboxGroupOption]
    @Binding var selectedIDs: Set<String>
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
                CheckboxOption(
                    title: option.title,
                    subtitle: option.subtitle,
                    isSelected: selectedIDs.contains(option.id)
                ) {
                    toggle(option.id)
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

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
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
    @Previewable @State var selection: Set<String> = ["seine"]
    return CheckboxGroup(
        options: [
            CheckboxGroupOption(id: "seine", title: "Seine nets (not specified)", subtitle: "100mm mesh", accessibilityIdentifier: "Preview.seine"),
            CheckboxGroupOption(id: "trawl", title: "Bottom trawl", accessibilityIdentifier: "Preview.trawl")
        ],
        selectedIDs: $selection,
        errorKey: "a11y.errorPrefix",
        groupAccessibilityIdentifier: "Preview.group",
        errorAccessibilityIdentifier: "Preview.error"
    )
    .padding()
    .environment(AppLanguageStore.preview)
}
