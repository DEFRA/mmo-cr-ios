import SwiftUI

/// The analytics-consent switch row on the Settings screen — see
/// docs/design-specs/settings.md (deviation #6: no toggle/switch component existed yet)
/// and deviation #7 (the mock has no visible label of its own; both `accessibilityLabel`
/// and `accessibilityHint` are authored explicitly rather than relying on the section
/// heading above).
///
/// State is conveyed by the standard iOS `Toggle`'s position/knob (and its "on"/"off"
/// accessibility value) — never by colour alone — satisfying WCAG 2.2 AA.
struct SettingsToggleRow: View {
    let accessibilityLabel: String
    let accessibilityHint: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            EmptyView()
        }
        .labelsHidden()
        .toggleStyle(.switch)
        .tint(AppColors.govBlue)
        .frame(minHeight: AppControlSize.minTapTarget, alignment: .leading)
        .accessibilityIdentifier("Settings.analyticsToggle")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}

#Preview("On") {
    SettingsToggleRow(
        accessibilityLabel: "Analytics data collection",
        accessibilityHint: "Double tap to turn analytics data collection off or on",
        isOn: .constant(true)
    )
    .padding()
}

#Preview("Off") {
    SettingsToggleRow(
        accessibilityLabel: "Analytics data collection",
        accessibilityHint: "Double tap to turn analytics data collection off or on",
        isOn: .constant(false)
    )
    .padding()
}

#Preview("Max Dynamic Type") {
    SettingsToggleRow(
        accessibilityLabel: "Analytics data collection",
        accessibilityHint: "Double tap to turn analytics data collection off or on",
        isOn: .constant(true)
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}
