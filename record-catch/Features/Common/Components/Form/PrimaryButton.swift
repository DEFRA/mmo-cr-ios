import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.button)
                .frame(maxWidth: .infinity)
                .frame(height: AppControlSize.buttonHeight)
                .foregroundStyle(Color.white)
                .background(isDisabled ? AppColors.textSecondary : AppColors.govGreen)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityHint(isDisabled ? "Complete required fields first" : "Saves and continues")
    }
}

#Preview {
    VStack(spacing: AppSpacing.small) {
        PrimaryButton(title: "Save and continue") {}
        PrimaryButton(title: "Save and continue", isDisabled: true) {}
    }
    .padding()
}
