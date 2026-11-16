//
//  AuthScreenScaffold.swift
//  record-catch
//
//  Shared layout scaffold for the plain, no-`ViewTemplate` auth-style screens: a top-right
//  language toggle, scrollable content and the plain app background. Used by the password
//  reset journey (ADR-0027) screens, which deliberately mirror `SignInView`'s plain layout
//  (no GOV.UK header bar, no footer) — see the comment at the top of `SignInView.body`.
//
//  Extracted to remove the duplicated wrapper that `CreateNewPasswordView`, `EnterResetCodeView`
//  and `ResetPasswordView` each repeated verbatim.
//

import SwiftUI

struct AuthScreenScaffold<Content: View>: View {

    @Environment(AppLanguageStore.self) private var languageStore
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                LanguageToggleButton(foregroundColor: AppColors.textPrimary)
            }
            .padding(.horizontal, AppSpacing.medium)

            ScrollView {
                content
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.large)
            }
        }
        .background(AppColors.background)
        // Locale drives formatting (dates/numbers). VoiceOver pronunciation of runtime strings
        // is handled per-part via `LocalizedText` carrying a language identifier (WCAG 3.1.2).
        .environment(\.locale, languageStore.language.locale)
    }
}

#Preview {
    AuthScreenScaffold {
        Text("Preview content")
    }
    .environment(AppLanguageStore.preview)
}
