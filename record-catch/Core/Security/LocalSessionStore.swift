//
//  LocalSessionStore.swift
//  record-catch
//
//  Marks whether a local "signed-in" session has been established on this device (ADR-0009).
//
//  This is **not** a backend session — no real authentication exists in this app yet — it only
//  records that the (currently stubbed) sign-in flow completed once, so the app root can offer
//  biometric re-entry instead of always showing the sign-in form again.
//

import Foundation

nonisolated protocol LocalSessionStoring: Sendable {
    /// Whether a local session marker is currently stored on this device.
    func hasLocalSession() -> Bool
    /// Records that a local session has started (call after a successful, currently-stubbed
    /// sign-in).
    func beginSession() throws
    /// Clears the local session marker (e.g. on explicit sign-out).
    func endSession() throws
}

/// Keychain-backed implementation. Stores a small, non-secret marker under
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — deliberately **not** biometric-gated (see
/// ADR-0009 §1); the biometric gate lives in `ReentrySecretStoring`.
nonisolated final class KeychainLocalSessionStore: LocalSessionStoring, @unchecked Sendable {
    private static let account = "session.marker"

    private let keychain: KeychainStoring

    init(keychain: KeychainStoring = KeychainStore()) {
        self.keychain = keychain
    }

    func hasLocalSession() -> Bool {
        keychain.itemExists(account: Self.account)
    }

    func beginSession() throws {
        try keychain.set(Data([1]), account: Self.account, accessControl: nil)
    }

    func endSession() throws {
        try keychain.removeItem(account: Self.account)
    }
}

/// In-memory, test/preview-only implementation.
nonisolated final class InMemoryLocalSessionStore: LocalSessionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var hasSession: Bool

    init(hasSession: Bool = false) {
        self.hasSession = hasSession
    }

    func hasLocalSession() -> Bool {
        lock.withLock { hasSession }
    }

    func beginSession() throws {
        lock.withLock { hasSession = true }
    }

    func endSession() throws {
        lock.withLock { hasSession = false }
    }
}
