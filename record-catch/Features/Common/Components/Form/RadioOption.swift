import SwiftUI

struct RadioOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.medium) {
                ZStack {
                    Circle()
                        .stroke(AppColors.borderStrong, lineWidth: 1)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(AppColors.borderStrong)
                            .frame(width: 12, height: 12)
                    }
                }

                Text(title)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppSpacing.medium) {
        RadioOption(title: "Yes", isSelected: true) {}
        RadioOption(title: "No", isSelected: false) {}
    }
    .padding()
}
