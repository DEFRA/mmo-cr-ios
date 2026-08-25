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
    /// Depends on the `HeaderNavigating` protocol, not the concrete `CatchRecordRouter`,
    /// so `Common` stays decoupled from the `CatchRecord` feature layer.
    @Environment(\.headerNavigator) private var navigator

    /// Scales the branding image with Dynamic Type (relative to `.headline`)
    /// so it grows in step with the surrounding text and survives 200% text
    /// sizes without clipping the 56pt header bar.
    @ScaledMetric(relativeTo: .headline) private var logoHeight: CGFloat = 18

    /// The back control is only shown when there is a screen to pop back to, so
    /// the journey root doesn't render a dead-end "Back" control.
    private var canGoBack: Bool {
        (navigator?.canGoBack == true)
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

            Image("GovUKHeader")
                .resizable()
                .scaledToFit()
                .frame(height: logoHeight)
                .accessibilityLabel(languageStore.localized("header.branding"))
                .accessibilityIdentifier("ViewHeader.branding")

            Spacer()

            LanguageToggleButton()
        }
        .padding(.horizontal, AppSpacing.medium)
        .frame(height: 56)
        .background(AppColors.govBlue)
    }

    private var backButton: some View {
        Button {
            navigator?.pop()
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
