//
//  ViewHeader.swift
//  record-catch
//
//  Created by Paul Halpin on 09/07/2026.
//

import SwiftUI

struct ViewHeader: View {

    @Environment(AppLanguageStore.self) private var languageStore
    /// Read optionally so `ViewHeader` still works in contexts without the
    /// "Create a catch record" journey stack (e.g. previews and demo screens).
    @Environment(CatchRecordRouter.self) private var router: CatchRecordRouter?

    /// The back control is only shown when there is a screen to pop back to, so
    /// the journey root doesn't render a dead-end "Back" control.
    private var canGoBack: Bool {
        (router?.path.isEmpty == false)
    }

    var body: some View {
        HStack {
            // Reserve the leading slot so the centred branding stays centred
            // whether or not the back button is present.
            Group {
                if canGoBack {
                    backButton
                } else {
                    backButton.hidden()
                }
            }

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

    private var backButton: some View {
        Button {
            router?.pop()
        } label: {
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: "chevron.left")
                    .accessibilityHidden(true)
                LocalizedText("header.back")
            }
            .font(AppTypography.bodySmall)
            .foregroundStyle(.white)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canGoBack)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(languageStore.localized("header.back"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("ViewHeader.backButton")
    }
}

#Preview {
    ViewHeader()
        .environment(AppLanguageStore.preview)
}
