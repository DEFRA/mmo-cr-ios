//
//  ResetPasswordView.swift
//  record-catch
//
//  "Reset your password" screen (AC1–AC3, AC9, ADR-0027). Layout mirrors `SignInView`'s plain,
//  no-`ViewTemplate` background (language toggle, crown logo, heading, form, grey crest footer).
//

import SwiftUI

struct ResetPasswordView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State var viewModel: ResetPasswordViewModel
    @AccessibilityFocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case formError
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
        .environment(\.locale, languageStore.language.locale)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            if viewModel.showFormErrorSummary, let key = viewModel.formError?.localizationKey {
                formErrorSummary(key: key)
            }

            Image("CrownLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

            LocalizedText("passwordReset.reset.heading")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("PasswordReset.heading")

            LocalizedText("passwordReset.reset.guidance")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityIdentifier("PasswordReset.guidance")

            emailSection

            PrimaryButton(
                title: languageStore.localized("passwordReset.sendCode.button"),
                isLoading: viewModel.isSubmitting,
                loadingAccessibilityLabel: languageStore.localized("passwordReset.a11y.sending"),
                accessibilityHintText: languageStore.localized("passwordReset.sendCode.a11y.hint")
            ) {
                Task { await submit() }
            }
            .accessibilityIdentifier("PasswordReset.sendCodeButton")

            crestFooter
        }
        .onChange(of: viewModel.formError) { _, newValue in
            guard newValue != nil, newValue != .missingOrInvalidEmail else { return }
            focusedField = .formError
        }
        .onChange(of: viewModel.emailFieldError) { _, newValue in
            guard newValue != nil else { return }
            focusedField = .email
        }
    }

    private func submit() async {
        await viewModel.submit()
    }

    private func formErrorSummary(key: String) -> some View {
        InlineErrorText(message: languageStore.localized(key), accessibilityIdentifier: "PasswordReset.formError")
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(AppColors.errorRed, lineWidth: 2))
            .accessibilityFocused($focusedField, equals: .formError)
    }

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            TextInputField(
                label: languageStore.localized("passwordReset.email.label"),
                hint: languageStore.localized("passwordReset.email.hint"),
                keyboardType: .emailAddress,
                textInputAutocapitalization: .never,
                autocorrectionDisabled: true,
                secureTextContentType: .username,
                labelColor: AppColors.textSecondary,
                text: emailBinding
            )
            .disabled(viewModel.isSubmitting)
            .accessibilityIdentifier("PasswordReset.emailField")
            .accessibilityFocused($focusedField, equals: .email)

            if let error = viewModel.emailFieldError {
                InlineErrorText(
                    message: languageStore.localized(error.localizationKey),
                    accessibilityIdentifier: "PasswordReset.emailError"
                )
            }
        }
    }

    private var emailBinding: Binding<String> {
        Binding(
            get: { viewModel.email },
            set: {
                viewModel.email = $0
                viewModel.clearFormError()
            }
        )
    }

    private var crestFooter: some View {
        Image("CrownLogoGrey")
            .resizable()
            .scaledToFit()
            .frame(height: 64)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, AppSpacing.large)
            .accessibilityHidden(true)
    }
}

#Preview {
    ResetPasswordView(viewModel: ResetPasswordViewModel(resetter: FakePasswordResetter(), router: PasswordResetRouter()))
        .environment(AppLanguageStore.preview)
}
