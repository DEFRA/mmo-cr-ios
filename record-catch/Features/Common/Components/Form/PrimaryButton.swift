import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isDisabled: Bool = false
    /// `true` while an async action triggered by this button is in flight: shows a progress
    /// indicator in place of the title, disables the button, and overrides `accessibilityHint`
    /// with `loadingAccessibilityLabel` (ADR-0022 — Sign In's EC1 loading state).
    var isLoading: Bool = false
    /// Announced to VoiceOver while `isLoading` is `true` (e.g. "Signing in"). Ignored otherwise.
    var loadingAccessibilityLabel: String = ""
    /// Accessibility hint shown when the button is enabled and not loading. Defaults to the
    /// original "Saves and continues" copy used by every call site except Sign In, which supplies
    /// its own ("Submits your sign in details").
    var accessibilityHintText: String = "Saves and continues"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(AppTypography.button)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppControlSize.buttonHeight)
            .foregroundStyle(Color.white)
            .background(isDisabled || isLoading ? AppColors.textSecondary : AppColors.govGreen)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(isLoading ? loadingAccessibilityLabel : title)
        .accessibilityHint(isDisabled ? "Complete required fields first" : accessibilityHintText)
    }
}

#Preview {
    VStack(spacing: AppSpacing.small) {
        PrimaryButton(title: "Save and continue") {}
        PrimaryButton(title: "Save and continue", isDisabled: true) {}
        PrimaryButton(title: "Sign in", isLoading: true, loadingAccessibilityLabel: "Signing in") {}
    }
    .padding()
}
