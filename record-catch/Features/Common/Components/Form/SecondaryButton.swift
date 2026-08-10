import SwiftUI

/// A secondary call-to-action button (GOV.UK Design System `govuk-button--secondary`).
///
/// Grey background with dark text for secondary actions such as "Add another port", used alongside
/// the green `PrimaryButton`. Full-width and 44pt tall to meet the WCAG 2.2 target-size minimum;
/// the grey-on-black pairing exceeds the 4.5:1 contrast requirement.
struct SecondaryButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.button)
                .frame(maxWidth: .infinity)
                .frame(height: AppControlSize.buttonHeight)
                .foregroundStyle(AppColors.textPrimary)
                .background(AppColors.surfaceMuted)
                .overlay(
                    Rectangle().stroke(AppColors.borderDefault, lineWidth: 1)
                )
                .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    VStack(spacing: AppSpacing.small) {
        PrimaryButton(title: "Save and continue") {}
        SecondaryButton(title: "Add another port") {}
    }
    .padding()
}
