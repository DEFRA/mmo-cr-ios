//  SignInView.swift
//  record-catch
//
//  Bilingual Sign In screen (ADR-0022): real Entra authentication via `SignInViewModel`.
//  Deliberately does NOT use the shared `ViewTemplate` — see the comment at the top of `body`
//  below (also means no offline banner here, see ADR-0019).
//

import SwiftUI

struct SignInView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SignInViewModel
    /// Moves VoiceOver focus to the first error after a failed submit (WCAG 2.2 AA — errors must
    /// be perceivable and easy to locate).
    @AccessibilityFocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email
        case password
        case formError
    }

    /// Called once sign-in succeeds. `RootSessionCoordinator.handleSignIn` is the real app-root
    /// handler; previews/tests that don't care about the destination can omit it.
    ///
    /// - Parameter authenticator: No default — Swift default-argument expressions are not
    ///   actor-isolated, so a `@MainActor`-isolated fake (e.g. `FakeAuthenticator()`) cannot be
    ///   constructed as one. Callers (`RecordCatchApp`, previews, tests) always supply one
    ///   explicitly.
    init(
        authenticator: any Authenticating,
        onSignIn: @escaping (AuthenticatedAccount) -> Void = { _ in /* no-op default: previews/tests that don't care about the destination */ }
    ) {
        _viewModel = State(initialValue: SignInViewModel(authenticator: authenticator, onSignedIn: onSignIn))
    }

    var body: some View {
        // The Sign In design has no GOV.UK header bar and no footer — just a
        // language toggle, the crown logo, heading, form and links on a plain
        // white background. So this screen does NOT use `ViewTemplate`.
        VStack(spacing: 0) {
            HStack {
                Spacer()
                // Per the sign-in design, the language toggle renders in the primary text
                // colour (black) rather than the link colour used elsewhere — contrast is
                // unaffected (black-on-white exceeds AA) and it remains visually distinct as a
                // bold abbreviation in the top-right corner.
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
        // Locale drives formatting (dates/numbers). VoiceOver pronunciation of
        // runtime strings is handled per-part via `LocalizedText` / `ErrorLabel`
        // carrying a language identifier (WCAG 3.1.2).
        .environment(\.locale, languageStore.language.locale)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            if viewModel.showFormErrorSummary, let formError = viewModel.formError, let key = formError.localizationKey {
                formErrorSummary(key: key)
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

            PrimaryButton(
                title: languageStore.localized("signIn.button"),
                isLoading: viewModel.isSubmitting,
                loadingAccessibilityLabel: languageStore.localized("signIn.a11y.signingIn"),
                accessibilityHintText: languageStore.localized("signIn.a11y.hint")
            ) {
                Task { await submit() }
            }
            .accessibilityIdentifier("SignIn.signInButton")

            troubleSection
        }
        .onChange(of: viewModel.formError) { _, newValue in
            guard newValue != nil, newValue != .missingOrInvalidFields else { return }
            focusedField = .formError
        }
        .onChange(of: viewModel.emailFieldError) { _, newValue in
            guard newValue != nil else { return }
            focusedField = .email
        }
    }

    private func submit() async {
        await viewModel.submit()
        // Move focus to the password error if the email was valid but the password wasn't —
        // `onChange(of: emailFieldError)` above only fires when the *email* field has an error.
        if viewModel.emailFieldError == nil, viewModel.passwordFieldError != nil {
            focusedField = .password
        }
    }

    // MARK: - Form error summary

    private func formErrorSummary(key: String) -> some View {
        ErrorLabel(key: key)
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                Rectangle().stroke(AppColors.errorRed, lineWidth: 2)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized(key))"
            )
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("SignIn.credentialError")
            .accessibilityFocused($focusedField, equals: .formError)
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
                labelColor: AppColors.textSecondary,
                text: emailBinding
            )
            .disabled(viewModel.isSubmitting)
            .accessibilityIdentifier("SignIn.emailField")
            .accessibilityFocused($focusedField, equals: .email)

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
                viewModel.clearFormError()
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
                labelColor: AppColors.textSecondary,
                text: passwordBinding
            )
            .disabled(viewModel.isSubmitting)
            .accessibilityFocused($focusedField, equals: .password)

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
                viewModel.clearFormError()
            }
        )
    }

    // MARK: - Trouble / links

    private var troubleSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            LocalizedText("signIn.trouble.heading")
                .font(AppTypography.troubleHeading)
                .lineSpacing(6)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("SignIn.troubleHeading")

            linkButton(key: "signIn.link.forgottenPassword", identifier: "SignIn.forgottenPasswordLink")
            createAccountSection
        }
    }

    /// "Create an account" — a GDS-style disclosure (reusing the shared
    /// `ExpandableHelpSection`, as used elsewhere e.g. Home's status-help section) rather than
    /// the inert link used for "Forgotten your password?" above. Tapping it reveals guidance for
    /// the two routes into the app: a vessel owner is invited automatically when their vessel is
    /// added, while a skipper/agent must be added by their vessel owner. It remains inert beyond
    /// expanding/collapsing — there is no account-creation flow in this phase (AC9).
    private var createAccountSection: some View {
        ExpandableHelpSection(
            title: languageStore.localized("signIn.link.createAccount"),
            accessibilityIdentifier: "SignIn.createAccountLink",
            // Match the font size of the "Forgotten your password?" link above
            // (`AppTypography.body`), rather than the `bodySmall` default used by
            // other `ExpandableHelpSection` call sites (e.g. Home's status-help
            // section), so the two Sign In links read at the same size.
            titleFont: AppTypography.body,
            items: [
                HelpItem(
                    heading: languageStore.localized("signIn.createAccount.vesselOwner.heading"),
                    description: languageStore.localized("signIn.createAccount.vesselOwner.body")
                ),
                HelpItem(
                    heading: languageStore.localized("signIn.createAccount.skipper.heading"),
                    description: languageStore.localized("signIn.createAccount.skipper.body")
                )
            ]
        )
    }

    /// "Forgotten your password?" — an inert link-styled button. Self-service password reset is
    /// deferred to a separate ticket (ADR-0022 §8, AC6); this screen never navigates anywhere.
    private func linkButton(key: String, identifier: String) -> some View {
        Button {
            // Intentionally inert — see the doc comment above (ADR-0022 §8).
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
/// inline field errors and the form error summary. Copy is rendered via
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
    SignInView(authenticator: FakeAuthenticator())
        .environment(AppLanguageStore.preview)
}
