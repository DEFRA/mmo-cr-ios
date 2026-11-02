//
//  OfflineAccessPolicy.swift
//  record-catch
//
//  Pure, stateless decision logic for the 7-day offline sign-in grace period (ADR-0022 §5). No
//  I/O — trivially unit-testable, per ADR-0001's "pure helper" pattern.
//

import Foundation

/// How long a previously-verified Entra session may be used while the device is offline.
nonisolated enum OfflineAccessPolicy: Sendable, Equatable {
    /// Never allow offline access — the user must be online.
    case disallowed
    /// Allow offline access for a number of days after the last successful **online**
    /// verification (sign-in, or a successful silent token refresh).
    case gracePeriod(days: Int)
    /// Allow offline access indefinitely after one successful sign-in (until sign-out).
    case indefinite

    /// The policy currently in force for this app (ADR-0022 §5: "offline should work for 7
    /// days").
    static let current: OfflineAccessPolicy = .gracePeriod(days: 7)

    /// Decides whether offline access is still allowed.
    ///
    /// A `lastVerified` time **after** `now` (e.g. device clock tampering) is always treated as
    /// *not* verified — never as "still fresh" — so a manipulated clock cannot extend offline
    /// access (ADR-0022 §5).
    func allowsOfflineAccess(lastVerified: Date?, now: Date = .now) -> Bool {
        guard let lastVerified, lastVerified <= now else { return false }
        switch self {
        case .disallowed:
            return false
        case .indefinite:
            return true
        case .gracePeriod(let days):
            return now.timeIntervalSince(lastVerified) <= TimeInterval(days) * 86_400
        }
    }
}
