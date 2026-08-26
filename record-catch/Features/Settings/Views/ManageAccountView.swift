//
//  ManageAccountView.swift
//  record-catch
//
//  "Manage your account" screen (see docs/design-specs/manage-account.md): a "Your details"
//  section (name / address / email / contact number, each with an inert "Change" seam) and a
//  "Sign in" section with a Face ID toggle. Reached from Settings' "My account" link via
//  `SettingsRouter` (see docs/adr/0007-settings-tab-navigation.md). The bottom TabBar stays
//  VISIBLE here — unlike the "Create a catch record" journey, this screen's design keeps the
//  tab chrome, so no `.toolbar(.hidden, for: .tabBar)` is applied.
//

import SwiftUI

struct ManageAccountView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: ManageAccountViewModel

    init(viewModel: ManageAccountViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? ManageAccountViewModel())
    }

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            // Deviation (see design spec's deviation register): the caption reads the literal
            // words "Business Name" in the source design — not a data-bound business name field
            // — so it is rendered as static, authored copy rather than an `Account` property.
            LocalizedText("manageAccount.caption")
                .font(AppTypography.pageCaption)
                .foregroundStyle(AppColors.govBlue)

            TitleText(text: languageStore.localized("manageAccount.title"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ManageAccount.title")

            yourDetailsSection

            Divider().overlay(AppColors.divider)

            signInSection
        }
    }

    @ViewBuilder
    private var yourDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(languageStore.localized("manageAccount.yourDetails.heading"))
                .font(AppTypography.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, AppSpacing.medium)

            detailRow(
                label: languageStore.localized("manageAccount.firstName.label"),
                value: viewModel.account.firstName,
                identifierSuffix: "firstName"
            ) {
                viewModel.changeFirstNameTapped()
            }
            Divider().overlay(AppColors.divider)

            detailRow(
                label: languageStore.localized("manageAccount.lastName.label"),
                value: viewModel.account.lastName,
                identifierSuffix: "lastName"
            ) {
                viewModel.changeLastNameTapped()
            }
            Divider().overlay(AppColors.divider)

            detailRow(
                label: languageStore.localized("manageAccount.address.label"),
                value: viewModel.account.address,
                identifierSuffix: "address"
            ) {
                viewModel.changeAddressTapped()
            }
            Divider().overlay(AppColors.divider)

            detailRow(
                label: languageStore.localized("manageAccount.email.label"),
                value: viewModel.account.email,
                identifierSuffix: "email"
            ) {
                viewModel.changeEmailTapped()
            }
            Divider().overlay(AppColors.divider)

            detailRow(
                label: languageStore.localized("manageAccount.contactNumber.label"),
                value: viewModel.account.contactNumber,
                identifierSuffix: "contactNumber"
            ) {
                viewModel.changeContactNumberTapped()
            }
        }
    }

    @ViewBuilder
    private func detailRow(
        label: String,
        value: String,
        identifierSuffix: String,
        onChange: @escaping () -> Void
    ) -> some View {
        SettingsValueRow(
            label: label,
            value: value,
            emptyStateValue: languageStore.localized("manageAccount.value.notProvided"),
            changeTitle: languageStore.localized("manageAccount.change"),
            changeAccessibilityIdentifier: "ManageAccount.change.\(identifierSuffix)",
            onChange: onChange
        )
    }

    @ViewBuilder
    private var signInSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(languageStore.localized("manageAccount.signIn.heading"))
                .font(AppTypography.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Text(languageStore.localized("manageAccount.faceID.heading"))
                .font(AppTypography.bodySmall.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            ParagraphText(text: languageStore.localized("manageAccount.faceID.hint"), isHint: true)

            if viewModel.enableFailedMessage {
                faceIDEnableFailedSummary
            }

            SettingsToggleRow(
                accessibilityIdentifier: "ManageAccount.faceIDToggle",
                accessibilityLabel: languageStore.localized("manageAccount.faceID.toggle.label"),
                accessibilityHint: languageStore.localized("manageAccount.faceID.toggle.hint"),
                isOn: faceIDToggleBinding
            )
        }
    }

    /// A live biometric enrolment check is required before the preference can turn on
    /// (ADR-0009 §8), so the toggle's `Bool` binding drives async view-model calls rather than
    /// writing straight to a stored property.
    private var faceIDToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.faceIDEnabled },
            set: { newValue in
                if newValue {
                    Task { await viewModel.enableFaceID() }
                } else {
                    viewModel.disableFaceID()
                }
            }
        )
    }

    private var faceIDEnableFailedSummary: some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            LocalizedText("manageAccount.faceID.enableFailed")
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(AppColors.errorRed, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized("manageAccount.faceID.enableFailed"))"
        )
        .accessibilityIdentifier("ManageAccount.faceIDEnableFailed")
    }
}

#Preview("English") {
    ManageAccountView(
        viewModel: ManageAccountViewModel(
            accountProvider: StubAccountProvider(),
            biometricStore: InMemoryBiometricPreferenceStore(),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore()
        )
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    ManageAccountView(
        viewModel: ManageAccountViewModel(
            accountProvider: StubAccountProvider(),
            biometricStore: InMemoryBiometricPreferenceStore(),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore()
        )
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Face ID on") {
    ManageAccountView(
        viewModel: ManageAccountViewModel(
            accountProvider: StubAccountProvider(),
            biometricStore: InMemoryBiometricPreferenceStore(initialValue: true),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore(exists: true)
        )
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Face ID enable failed") {
    ManageAccountView(
        viewModel: ManageAccountViewModel(
            accountProvider: StubAccountProvider(),
            biometricStore: InMemoryBiometricPreferenceStore(),
            biometricAuthenticator: FakeBiometricAuthenticator(
                availability: .unavailable(.noBiometryEnrolled),
                authenticateResult: .failure(.biometryNotEnrolled)
            ),
            secretStore: InMemoryReentrySecretStore()
        )
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Max Dynamic Type") {
    ManageAccountView(
        viewModel: ManageAccountViewModel(
            accountProvider: StubAccountProvider(),
            biometricStore: InMemoryBiometricPreferenceStore(),
            biometricAuthenticator: FakeBiometricAuthenticator(),
            secretStore: InMemoryReentrySecretStore()
        )
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
