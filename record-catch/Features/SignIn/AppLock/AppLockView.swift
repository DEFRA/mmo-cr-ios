//
//  AppLockView.swift
//  record-catch
//
//  Offline biometric local re-entry ("app lock") screen — see ADR-0009. Mirrors `SignInView`'s
//  plain, no-`ViewTemplate` layout (no GOV.UK header/footer on this screen either). Always shows
//  a manual "sign in with your password instead" link so the user is never dead-ended, per
//  accessibility.instructions.md.
//

import SwiftUI

struct AppLockView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: AppLockViewModel

    init(viewModel: AppLockViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                content
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.top, AppSpacing.xLarge)
                    .padding(.bottom, AppSpacing.large)
            }
        }
        .background(AppColors.background)
        .environment(\.locale, languageStore.language.locale)
        .task {
            viewModel.evaluateOffer()
        }
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

            LocalizedText("appLock.heading")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("AppLock.heading")

            if case .locked(let message) = viewModel.state, let message {
                failureSummary(for: message)
            }

            if viewModel.biometryKind == .faceID {
                // Face ID scans immediately with no explicit "start" step, so a pre-scan hint is
                // shown so VoiceOver/Dynamic Type users aren't surprised (Apple HIG guidance).
                ParagraphText(text: languageStore.localized("appLock.faceID.scanHint"), isHint: true)
                    .accessibilityIdentifier("AppLock.faceIDHint")
            }

            PrimaryButton(title: unlockButtonTitle) {
                Task { await viewModel.authenticate() }
            }
            .accessibilityIdentifier("AppLock.unlockButton")

            fallbackLink
        }
    }

    private var unlockButtonTitle: String {
        switch viewModel.biometryKind {
        case .faceID:
            return languageStore.localized("appLock.unlock.faceID")
        case .touchID:
            return languageStore.localized("appLock.unlock.touchID")
        case .opticID, .none:
            return languageStore.localized("appLock.unlock.generic")
        }
    }

    private var fallbackLink: some View {
        Button {
            viewModel.useSignInInstead()
        } label: {
            LocalizedText("appLock.fallback.link")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.linkText)
                .underline()
                .frame(maxWidth: .infinity, minHeight: AppControlSize.minTapTarget, alignment: .center)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
        .accessibilityIdentifier("AppLock.passwordFallbackLink")
    }

    private func failureSummary(for message: AppLockFailureMessage) -> some View {
        let key: String
        switch message {
        case .authenticationFailed: key = "appLock.error.authenticationFailed"
        case .biometryLockedOut: key = "appLock.error.biometryLockedOut"
        case .biometryUnavailable: key = "appLock.error.biometryUnavailable"
        case .cancelled: key = "appLock.error.cancelled"
        }
        return HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            LocalizedText(key)
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(AppColors.errorRed, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized(key))")
        .accessibilityIdentifier("AppLock.error")
    }
}

#Preview("Face ID") {
    AppLockView(
        viewModel: AppLockViewModel(
            biometricAuthenticator: FakeBiometricAuthenticator(availability: .available(.faceID)),
            sessionStore: InMemoryLocalSessionStore(hasSession: true),
            secretStore: InMemoryReentrySecretStore(exists: true),
            preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
            unlockReason: "Sign back in to your catch records"
        )
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Failed attempt") {
    let viewModel = AppLockViewModel(
        biometricAuthenticator: FakeBiometricAuthenticator(
            availability: .available(.faceID),
            authenticateResult: .failure(.authenticationFailed)
        ),
        sessionStore: InMemoryLocalSessionStore(hasSession: true),
        secretStore: InMemoryReentrySecretStore(exists: true, verifyError: BiometricError.authenticationFailed),
        preferenceStore: InMemoryBiometricPreferenceStore(initialValue: true),
        unlockReason: "Sign back in to your catch records"
    )
    return AppLockView(viewModel: viewModel)
        .environment(AppLanguageStore.preview)
}
