//
//  ViewHeader.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewHeader: View {

    @Environment(AppLanguageStore.self) private var languageStore

    var body: some View {
        HStack {
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: "chevron.left")
                    .accessibilityHidden(true)
                LocalizedText("header.back")
            }
            .font(AppTypography.bodySmall)
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(languageStore.localized("header.back"))
            .accessibilityAddTraits(.isButton)

            Spacer()

            LocalizedText("header.branding")
                .font(AppTypography.headerTitle)
                .foregroundStyle(.white)

            Spacer()

            LanguageToggleButton()
        }
        .padding(.horizontal, AppSpacing.medium)
        .frame(height: 56)
        .background(AppColors.govBlue)
    }
}

#Preview {
    ViewHeader()
        .environment(AppLanguageStore.preview)
}
