//
//  AuthTokenProviding.swift
//  record-catch
//
//  Bearer-token seam pending real OAuth/OIDC authentication (see ADR-0018 §5). The only concrete
//  implementation, `EnvironmentTokenProvider`, is compiled solely under `#if DEBUG` — no
//  production/Release code path can ever reach it. Its successor, once real auth lands, is a
//  `KeychainStoring`-backed provider (see Core/Security/KeychainStoring.swift).
//

import Foundation

/// Supplies the bearer token for reference-data API requests, or `nil` when none is available
/// (the request is then sent without an `Authorization` header — see `ReferenceDataEndpoint`).
nonisolated protocol AuthTokenProviding: Sendable {
    func bearerToken() async throws -> String?
}

#if DEBUG || ENABLE_DEBUG_REFERENCE_DATA_TOOL
/// DEBUG-only token source: reads `REFERENCE_DATA_API_TOKEN` from the process environment.
/// **No default value is ever committed** — returns `nil` when unset or blank, which surfaces as
/// `APIError.unauthorized` from the real API rather than a silent failure (see ADR-0018 §5).
///
/// Also compiled under the TEMPORARY `ENABLE_DEBUG_REFERENCE_DATA_TOOL` flag (see
/// Config/Release.xcconfig) so `SettingsViewModel`'s "DEBUG BUILD ONLY" species-fetch tool can
/// resolve a token in an Archive/TestFlight build too — remove this condition back to plain
/// `#if DEBUG` when that temporary tool is removed.
nonisolated struct EnvironmentTokenProvider: AuthTokenProviding {
    private let environment: [String: String]

    /// - Parameter environment: Defaults to `ProcessInfo.processInfo.environment`; overridable in
    ///   tests.
    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    func bearerToken() async throws -> String? {
        guard let token = environment["REFERENCE_DATA_API_TOKEN"] else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
#endif
