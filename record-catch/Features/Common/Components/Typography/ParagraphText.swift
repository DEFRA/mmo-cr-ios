import SwiftUI

struct ParagraphText: View {
    let text: String
    var isHint: Bool = false

    var body: some View {
        Text(text)
            .font(isHint ? AppTypography.hint : AppTypography.body)
            .foregroundStyle(isHint ? AppColors.textSecondary : AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: AppSpacing.small) {
        ParagraphText(text: "Select yes if you're recording today's trip now.")
        ParagraphText(text: "For example, 31/03/2020", isHint: true)
    }
    .padding()
}
