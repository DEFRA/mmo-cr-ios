//
//  PasswordResetCompleteView.swift
//  record-catch
//
//  "Your password has been reset" confirmation screen (AC17, ADR-0027). No automatic sign-in
//  (ADR-0027 §4) — the user explicitly returns to Sign In via the button below.
//

import SwiftUI

struct PasswordResetCompleteView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    let onSignIn: () -> Void

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
        .environment(\.locale, languageStore.language.locale)
        // The user has just completed a security-sensitive action and must land somewhere
        // deliberate, not be able to swipe back into a stale reset-code/password screen.
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Image("CrownLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

            LocalizedText("passwordReset.complete.heading")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("PasswordReset.complete.heading")

            PrimaryButton(title: languageStore.localized("signIn.button")) {
                onSignIn()
            }
            .accessibilityIdentifier("PasswordReset.complete.signInButton")
        }
    }
}

#Preview {
    PasswordResetCompleteView(onSignIn: {})
        .environment(AppLanguageStore.preview)
}
