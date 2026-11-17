//
//  CreateNewPasswordView.swift
//  record-catch
//
//  "Create a new password" screen (AC11–AC16, ADR-0027). Uses `SecureToggleStyle.text` for the
//  Show/Hide controls per the supplied design (ADR-0027 §9 deviation #2 — text buttons, not the
//  app's usual eye icon; the design's yellow fill is a web focus style and is not reproduced).
//

import SwiftUI

struct CreateNewPasswordView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State var viewModel: CreateNewPasswordViewModel
    @AccessibilityFocusState private var focusedField: Field?

    private enum Field: Hashable {
        case newPassword
        case confirmPassword
        case formError
    }

    var body: some View {
        AuthScreenScaffold {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            if viewModel.showFormErrorSummary, let key = viewModel.formError?.localizationKey {
                formErrorSummary(key: key)
            }

            CrownLogoHeader()

            LocalizedText("passwordReset.createPassword.heading")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("PasswordReset.createPassword.heading")

            newPasswordSection
            confirmPasswordSection

            PrimaryButton(
                title: languageStore.localized("passwordReset.savePassword.button"),
                isLoading: viewModel.isSubmitting,
                loadingAccessibilityLabel: languageStore.localized("passwordReset.a11y.saving"),
                accessibilityHintText: languageStore.localized("passwordReset.savePassword.a11y.hint")
            ) {
                Task { await viewModel.submit() }
            }
            .accessibilityIdentifier("PasswordReset.savePasswordButton")
        }
        .onChange(of: viewModel.formError) { _, newValue in
            guard newValue != nil, newValue != .missingOrInvalidFields else { return }
            focusedField = .formError
        }
        .onChange(of: viewModel.newPasswordFieldError) { _, newValue in
            guard newValue != nil else { return }
            focusedField = .newPassword
        }
        .onChange(of: viewModel.confirmPasswordFieldError) { _, newValue in
            guard newValue != nil, viewModel.newPasswordFieldError == nil else { return }
            focusedField = .confirmPassword
        }
    }

    private func formErrorSummary(key: String) -> some View {
        InlineErrorText(message: languageStore.localized(key), accessibilityIdentifier: "PasswordReset.createPassword.formError")
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(AppColors.errorRed, lineWidth: 2))
            .accessibilityFocused($focusedField, equals: .formError)
    }

    private var toggleStyle: SecureToggleStyle {
        .text(
            show: languageStore.localized("passwordReset.password.show"),
            hide: languageStore.localized("passwordReset.password.hide"),
            showAccessibilityLabel: languageStore.localized("passwordReset.password.a11y.show"),
            hideAccessibilityLabel: languageStore.localized("passwordReset.password.a11y.hide")
        )
    }

    private var newPasswordSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            TextInputField(
                label: languageStore.localized("passwordReset.newPassword.label"),
                hint: languageStore.localized("passwordReset.newPassword.hint"),
                isSecure: true,
                secureTextContentType: .newPassword,
                secureToggleStyle: toggleStyle,
                labelColor: AppColors.textSecondary,
                text: newPasswordBinding
            )
            .disabled(viewModel.isSubmitting)
            .accessibilityIdentifier("PasswordReset.newPasswordField")
            .accessibilityFocused($focusedField, equals: .newPassword)

            if let error = viewModel.newPasswordFieldError {
                InlineErrorText(
                    message: languageStore.localized(error.localizationKey),
                    accessibilityIdentifier: "PasswordReset.newPasswordError"
                )
            }
        }
    }

    private var confirmPasswordSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            TextInputField(
                label: languageStore.localized("passwordReset.confirmPassword.label"),
                isSecure: true,
                secureTextContentType: .newPassword,
                secureToggleStyle: toggleStyle,
                labelColor: AppColors.textSecondary,
                text: confirmPasswordBinding
            )
            .disabled(viewModel.isSubmitting)
            .accessibilityIdentifier("PasswordReset.confirmPasswordField")
            .accessibilityFocused($focusedField, equals: .confirmPassword)

            if let error = viewModel.confirmPasswordFieldError {
                InlineErrorText(
                    message: languageStore.localized(error.localizationKey),
                    accessibilityIdentifier: "PasswordReset.confirmPasswordError"
                )
            }
        }
    }

    private var newPasswordBinding: Binding<String> {
        Binding(
            get: { viewModel.newPassword },
            set: {
                viewModel.newPassword = $0
                viewModel.clearFormError()
            }
        )
    }

    private var confirmPasswordBinding: Binding<String> {
        Binding(
            get: { viewModel.confirmPassword },
            set: {
                viewModel.confirmPassword = $0
                viewModel.clearFormError()
            }
        )
    }
}

#Preview {
    CreateNewPasswordView(viewModel: CreateNewPasswordViewModel(resetter: FakePasswordResetter(), router: PasswordResetRouter()))
        .environment(AppLanguageStore.preview)
}
