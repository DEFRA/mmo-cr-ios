//
//  EnterResetCodeView.swift
//  record-catch
//
//  "Enter your reset code" screen (AC5–AC10, ADR-0027).
//

import SwiftUI

struct EnterResetCodeView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State var viewModel: EnterResetCodeViewModel
    @AccessibilityFocusState private var focusedField: Field?

    private enum Field: Hashable {
        case code
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

            LocalizedText("passwordReset.enterCode.heading")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("PasswordReset.enterCode.heading")

            LocalizedText("passwordReset.enterCode.guidance")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityIdentifier("PasswordReset.enterCode.guidance")

            codeSection

            PrimaryButton(
                title: languageStore.localized("passwordReset.continue.button"),
                isLoading: viewModel.isSubmitting,
                loadingAccessibilityLabel: languageStore.localized("passwordReset.a11y.verifying"),
                accessibilityHintText: languageStore.localized("passwordReset.continue.a11y.hint")
            ) {
                Task { await viewModel.submit() }
            }
            .accessibilityIdentifier("PasswordReset.continueButton")

            SecondaryButton(
                title: languageStore.localized("passwordReset.sendNewCode.button"),
                isDisabled: viewModel.isSubmitting
            ) {
                viewModel.requestNewCode()
            }
            .accessibilityIdentifier("PasswordReset.sendNewCodeButton")
        }
        .onChange(of: viewModel.formError) { _, newValue in
            guard newValue != nil, newValue != .missingCode else { return }
            focusedField = .formError
        }
        .onChange(of: viewModel.codeFieldError) { _, newValue in
            guard newValue != nil else { return }
            focusedField = .code
        }
    }

    private func formErrorSummary(key: String) -> some View {
        InlineErrorText(message: languageStore.localized(key), accessibilityIdentifier: "PasswordReset.enterCode.formError")
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(AppColors.errorRed, lineWidth: 2))
            .accessibilityFocused($focusedField, equals: .formError)
    }

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            TextInputField(
                label: languageStore.localized("passwordReset.code.label"),
                textInputAutocapitalization: .characters,
                autocorrectionDisabled: true,
                labelColor: AppColors.textSecondary,
                text: codeBinding
            )
            .disabled(viewModel.isSubmitting)
            .accessibilityIdentifier("PasswordReset.codeField")
            .accessibilityFocused($focusedField, equals: .code)

            if let error = viewModel.codeFieldError {
                InlineErrorText(
                    message: languageStore.localized(error.localizationKey),
                    accessibilityIdentifier: "PasswordReset.codeError"
                )
            }
        }
    }

    private var codeBinding: Binding<String> {
        Binding(
            get: { viewModel.code },
            set: {
                viewModel.code = $0
                viewModel.clearFormError()
            }
        )
    }
}

#Preview {
    EnterResetCodeView(viewModel: EnterResetCodeViewModel(resetter: FakePasswordResetter(), router: PasswordResetRouter()))
        .environment(AppLanguageStore.preview)
}
