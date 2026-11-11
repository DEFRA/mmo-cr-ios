//
//  SignInFlowView.swift
//  record-catch
//
//  Hosts the Sign In screen plus the password-reset journey pushed on top of it (ADR-0027 §8).
//  `SignInView` is the `NavigationStack`'s root; `PasswordResetRouter.path` drives everything
//  pushed above it. Also overlays `OfflineAuthPanel` whenever the device is offline, replacing
//  ADR-0019's "no offline UI on Sign In" rule for this pre-authentication surface (ADR-0027 §7).
//

import SwiftUI

struct SignInFlowView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(\.connectivityMonitor) private var connectivityMonitor
    @State private var router = PasswordResetRouter()

    let authenticator: any Authenticating
    let passwordResetter: any PasswordResetting
    let onSignIn: (AuthenticatedAccount) -> Void

    init(
        authenticator: any Authenticating,
        passwordResetter: any PasswordResetting,
        onSignIn: @escaping (AuthenticatedAccount) -> Void = { _ in }
    ) {
        self.authenticator = authenticator
        self.passwordResetter = passwordResetter
        self.onSignIn = onSignIn
    }

    private var isOffline: Bool { connectivityMonitor?.isOnline == false }

    var body: some View {
        NavigationStack(path: Binding(get: { router.path }, set: { router.setPath($0) })) {
            SignInView(authenticator: authenticator, onSignIn: onSignIn, onForgottenPassword: {
                router.start()
            })
            .navigationDestination(for: PasswordResetRoute.self) { route in
                destination(for: route)
            }
        }
        .fullScreenCover(isPresented: .constant(isOffline)) {
            OfflineAuthPanel(
                title: languageStore.localized("passwordReset.offline.title"),
                message: languageStore.localized("passwordReset.offline.message"),
                signInButtonTitle: languageStore.localized("signIn.button"),
                onSignIn: {
                    passwordResetter.cancel()
                    router.finish()
                }
            )
        }
    }

    @ViewBuilder
    private func destination(for route: PasswordResetRoute) -> some View {
        switch route {
        case .resetPassword(let attempt):
            // `.id(attempt)` forces SwiftUI to treat each restart as a distinct view identity
            // (AC9 — "Send a new code" must land on a genuinely fresh, blank email field), rather
            // than relying solely on `PasswordResetRoute`'s own `Hashable` conformance to drive
            // `navigationDestination(for:)`'s identity.
            ResetPasswordView(viewModel: ResetPasswordViewModel(resetter: passwordResetter, router: router))
                .id(attempt)
        case .enterCode:
            EnterResetCodeView(viewModel: EnterResetCodeViewModel(resetter: passwordResetter, router: router))
        case .createPassword:
            CreateNewPasswordView(viewModel: CreateNewPasswordViewModel(resetter: passwordResetter, router: router))
        case .complete:
            PasswordResetCompleteView(onSignIn: { router.finish() })
        }
    }
}
