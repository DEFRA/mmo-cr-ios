//
//  MSALAccessTokenProvider.swift
//  record-catch
//
//  Bridges the main-actor `Authenticating` seam (ADR-0022) to the `nonisolated`
//  `AuthTokenProviding` seam the Catch Recording Service connector depends on (ADR-0025). The only
//  production `AuthTokenProviding` backed by real sign-in: every other conformance
//  (`NilAuthTokenProvider`, `EnvironmentTokenProvider`) is either a placeholder or DEBUG-only.
//
//  The token itself is never cached, stored, or logged by this type — it is resolved fresh from
//  `Authenticating.accessToken()` (MSAL's own Keychain-backed cache) on every call, matching
//  ADR-0022 §4's "MSAL's own Keychain cache is the only place tokens should live".
//

import Foundation

/// Adapts a main-actor `Authenticating` into the `nonisolated`, `Sendable` `AuthTokenProviding`
/// seam used by `CatchRecordService`/`VesselFavouritesService` (ADR-0025).
///
/// Holds its `Authenticating` behind a `@MainActor` closure rather than a stored property, so this
/// type itself can be `nonisolated`/`Sendable` (required by `AuthTokenProviding`) without declaring
/// its own actor isolation — every call simply hops to the main actor to read the token, mirroring
/// how `CatchRecordDraft`'s `nonisolated init` only ever touches its own state on the main actor in
/// practice.
nonisolated struct MSALAccessTokenProvider: AuthTokenProviding {
    private let resolveToken: @MainActor () async -> String?

    /// - Parameter authenticator: The app's single `Authenticating` instance (see
    ///   `RootSessionCoordinator`). Captured as a `@MainActor`-isolated closure, not stored
    ///   directly, so this type stays `Sendable` without `authenticator` itself needing to be.
    init(authenticator: @MainActor @escaping () -> any Authenticating) {
        self.resolveToken = { await authenticator().accessToken() }
    }

    func bearerToken() async throws -> String? {
        await resolveToken()
    }
}
