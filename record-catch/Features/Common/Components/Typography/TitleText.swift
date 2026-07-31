import SwiftUI

struct TitleText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTypography.pageTitle)
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    TitleText(text: "Did your trip start and finish today?")
        .padding()
}
