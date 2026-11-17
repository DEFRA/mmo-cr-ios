//
//  OfflineAuthPanel.swift
//  record-catch
//
//  Full-screen "You are offline" panel shown on the Sign In screen and throughout the
//  password-reset journey while the device has no connectivity (ADR-0027 §7, narrows ADR-0019's
//  "no offline UI on Sign In" rule for the pre-authentication surface). Distinct from the
//  post-authentication `OfflineBanner`, which stays a top-of-content banner.
//

import SwiftUI

struct OfflineAuthPanel: View {
    let title: String
    let message: String
    let signInButtonTitle: String
    /// Called when the user taps the panel's "Sign in" button (AC18) — ends any in-flight
    /// password-reset journey and returns to/stays on Sign In.
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Text(title)
                .font(AppTypography.pageTitle)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("OfflineAuthPanel.title")

            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(.white)
                .accessibilityIdentifier("OfflineAuthPanel.message")

            Button(action: onSignIn) {
                Text(signInButtonTitle)
                    .font(AppTypography.button)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppControlSize.buttonHeight)
                    .foregroundStyle(AppColors.govBlue)
                    .background(.white)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("OfflineAuthPanel.signInButton")

            Spacer()
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColors.govBlue)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("OfflineAuthPanel")
    }
}

#Preview {
    OfflineAuthPanel(
        title: "You are offline",
        message: "Connect to the internet and try again.",
        signInButtonTitle: "Sign in",
        onSignIn: {}
    )
}
