//
//  BackendHealthStatusViewModel.swift
//  record-catch
//
//  Temporary, local-build-only backend connectivity check (see BackendHealthChecker.swift).
//

#if BACKEND_HEALTH_CHECK
import Foundation

/// Drives `BackendHealthStatusView`: runs the check and exposes its result once known.
///
/// `status` stays `nil` while the check is in flight (the view shows nothing, never an endless
/// spinner-with-no-text), matching the error-handling standard's "no silent/endless loading" rule.
@MainActor
@Observable
final class BackendHealthStatusViewModel {

    private(set) var status: BackendHealthStatus?

    private let checker: (@Sendable () async -> BackendHealthStatus)

    init(checker: @escaping @Sendable () async -> BackendHealthStatus = { await BackendHealthChecker.check() }) {
        self.checker = checker
    }

    /// Runs the check. Safe to call again on every screen appearance (`.task` re-runs each time
    /// `SignInView` appears), so a transient failure can self-heal without restarting the app.
    func check() async {
        status = await checker()
    }
}
#endif
