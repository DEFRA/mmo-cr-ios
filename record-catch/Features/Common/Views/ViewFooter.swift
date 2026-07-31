//
//  ViewFooter.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewFooter: View {
    var body: some View {
        Divider()
            .padding(.top, AppSpacing.large)

        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("Support")
                .font(AppTypography.footerHeading)

            Link(
                "Contact Defra",
                destination: URL(string: "https://www.gov.uk")!
            )
            .font(AppTypography.bodySmall)

            Text("© Crown copyright")
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, AppSpacing.medium)
    }
}

#Preview {
    ViewFooter()
}
