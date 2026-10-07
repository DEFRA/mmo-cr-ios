//
//  BackendHealthStatusView.swift
//  record-catch
//
//  Temporary, local-build-only backend connectivity check — shown at the bottom of Sign In only
//  when `BACKEND_HEALTH_CHECK` is set (see Config/Local.xcconfig.example). Hard-coded English
//  only: localisation is explicitly out of scope for this local diagnostic.
//

#if BACKEND_HEALTH_CHECK
import SwiftUI

struct BackendHealthStatusView: View {

    @State private var viewModel: BackendHealthStatusViewModel

    init(viewModel: BackendHealthStatusViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? BackendHealthStatusViewModel())
    }

    var body: some View {
        Group {
            if let status = viewModel.status {
                statusRow(for: status)
            }
        }
        .task {
            await viewModel.check()
        }
        .onChange(of: viewModel.status) { _, newStatus in
            guard let newStatus else { return }
            AccessibilityAnnouncer.announce(message(for: newStatus))
        }
    }

    @ViewBuilder
    private func statusRow(for status: BackendHealthStatus) -> some View {
        HStack(spacing: AppSpacing.xSmall) {
            Image(systemName: iconName(for: status))
                .foregroundStyle(color(for: status))
                .accessibilityHidden(true)
            Text(message(for: status))
                .font(AppTypography.bodySmall)
                .foregroundStyle(color(for: status))
        }
        .padding(AppSpacing.small)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("SignIn.backendHealthStatus")
    }

    private func message(for status: BackendHealthStatus) -> String {
        switch status {
        case .healthy: "Backend service healthy"
        case .connectivityError: "Connectivity error"
        }
    }

    private func iconName(for status: BackendHealthStatus) -> String {
        switch status {
        case .healthy: "checkmark.circle.fill"
        case .connectivityError: "exclamationmark.circle.fill"
        }
    }

    // Reuses existing, already-contrast-verified tokens (see docs/design-specs/sign-in.md /
    // home.md contrast notes) rather than introducing new colours for this temporary diagnostic.
    private func color(for status: BackendHealthStatus) -> Color {
        switch status {
        case .healthy: AppColors.statusSubmittedText
        case .connectivityError: AppColors.errorRed
        }
    }
}

#Preview("Healthy") {
    BackendHealthStatusView(viewModel: BackendHealthStatusViewModel(checker: { .healthy }))
}

#Preview("Connectivity error") {
    BackendHealthStatusView(viewModel: BackendHealthStatusViewModel(checker: { .connectivityError }))
}
#endif
