//
//  ViewHeader.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewHeader: View {
    var body: some View {
        HStack {
            Text("< Back")
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white)

            Spacer()

            Text("GOV.UK")
                .font(AppTypography.headerTitle)
                .foregroundStyle(.white)

            Spacer()

            Text("CYM")
                .font(AppTypography.bodySmall)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, AppSpacing.medium)
        .frame(height: 56)
        .background(AppColors.govBlue)
    }
}

#Preview {
    ViewHeader()
}
