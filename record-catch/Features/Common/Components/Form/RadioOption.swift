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
            }
            // No trailing `Spacer()`: the tappable area hugs the radio glyph + label (padded up
            // to the 44×44pt minimum), rather than stretching across the rest of the row's blank
            // trailing space — mirroring the `LinkButton`/`AppLockView` fix for the same issue.
            .frame(minWidth: AppControlSize.minTapTarget, minHeight: AppControlSize.minTapTarget, alignment: .leading)
            .contentShape(Rectangle())
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
