//  SignInView.swift
//  record-catch
//
//  UI-only bilingual Sign In screen, rendered inside the shared ViewTemplate.
//

import SwiftUI

struct SignInView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel = SignInViewModel()

    var body: some View {
        // The Sign In design has no GOV.UK header bar and no footer — just a
        // language toggle, the crown logo, heading, form and links on a plain
        // white background. So this screen does NOT use `ViewTemplate`.
        VStack(spacing: 0) {
            HStack {
                Spacer()
                LanguageToggleButton(foregroundColor: AppColors.linkText)
            }
            .padding(.horizontal, AppSpacing.medium)

            ScrollView {
                content
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.large)
            }
        }
        .background(AppColors.background)
        // Locale drives formatting (dates/numbers). VoiceOver pronunciation of
        // runtime strings is handled per-part via `LocalizedText` / `ErrorLabel`
        // carrying a language identifier (WCAG 3.1.2).
        .environment(\.locale, languageStore.language.locale)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            if viewModel.showInvalidCredentials {
                credentialErrorSummary
            }

            // DEFRA crown logo, centred above the heading (per design).
            Image("CrownLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

            LocalizedText("signIn.heading")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("SignIn.heading")

            emailSection
            passwordSection

            PrimaryButton(title: languageStore.localized("signIn.button")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("SignIn.signInButton")

            troubleSection
        }
    }

    // MARK: - Credential error summary

    private var credentialErrorSummary: some View {
        ErrorLabel(key: "signIn.error.credentials")
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                Rectangle().stroke(AppColors.errorRed, lineWidth: 2)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized("signIn.error.credentials"))"
            )
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("SignIn.credentialError")
    }

    // MARK: - Email

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            TextInputField(
                label: languageStore.localized("signIn.email.label"),
                keyboardType: .emailAddress,
                textInputAutocapitalization: .never,
                autocorrectionDisabled: true,
                secureTextContentType: .username,
                text: emailBinding
            )
            .accessibilityIdentifier("SignIn.emailField")

            if let error = viewModel.emailFieldError {
                errorRow(key: error.localizationKey, identifier: "SignIn.emailError")
            }
        }
    }

    private var emailBinding: Binding<String> {
        Binding(
            get: { viewModel.email },
            set: {
                viewModel.email = $0
                viewModel.clearCredentialError()
            }
        )
    }

    // MARK: - Password

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            // NOTE: We intentionally do NOT set a `SignIn.passwordField` identifier
            // here. `TextInputField` is a composite and an outer identifier is
            // swallowed by the inner secure input. The password field is addressed
            // in tests via the inner `TextInputField.secureInput` /
            // `TextInputField.secureToggle` identifiers instead.
            TextInputField(
                label: languageStore.localized("signIn.password.label"),
                isSecure: true,
                secureTextContentType: .password,
                text: passwordBinding
            )

            if let error = viewModel.passwordFieldError {
                errorRow(key: error.localizationKey, identifier: "SignIn.passwordError")
            }
        }
    }

    private var passwordBinding: Binding<String> {
        Binding(
            get: { viewModel.password },
            set: {
                viewModel.password = $0
                viewModel.clearCredentialError()
            }
        )
    }

    // MARK: - Trouble / links

    private var troubleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            LocalizedText("signIn.trouble.heading")
                .font(AppTypography.footerHeading)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("SignIn.troubleHeading")

            linkButton(key: "signIn.link.forgottenPassword", identifier: "SignIn.forgottenPasswordLink")
            linkButton(key: "signIn.link.createAccount", identifier: "SignIn.createAccountLink")
        }
    }

    private func linkButton(key: String, identifier: String) -> some View {
        // Intentionally inert in this UI-only phase — navigates nowhere yet.
        Button {
            // No destination yet (future phase).
        } label: {
            LocalizedText(key)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.linkText)
                .underline()
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Error row

    private func errorRow(key: String, identifier: String) -> some View {
        ErrorLabel(key: key)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized(key))")
            .accessibilityIdentifier(identifier)
    }
}

/// Reusable icon + localized error message pair, rendered in `errorRed`.
///
/// Encapsulates the duplicated icon + `errorRed` error-text pattern used by the
/// inline field errors and the credential summary. Copy is rendered via
/// `LocalizedText` so it carries the correct language identifier for VoiceOver.
private struct ErrorLabel: View {
    let key: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            LocalizedText(key)
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
    }
}

#Preview {
    SignInView()
        .environment(AppLanguageStore.preview)
}
