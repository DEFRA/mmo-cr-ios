//
//  SessionVerificationStore.swift
//  record-catch
//
//  Records *when* the Entra session was last verified online (ADR-0022 §4/§5) — never a token.
//  Mirrors the non-secret "session marker" pattern in `LocalSessionStore.swift` (ADR-0009 §1):
//  stored under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `ThisDeviceOnly` (never
//  iCloud-synced), not biometric-gated.
//

import Foundation

nonisolated protocol SessionVerificationStoring: Sendable {
    /// The last time the session was verified online, or `nil` if never verified (or cleared).
    func lastVerified() -> Date?
    /// Records that the session was just verified online (sign-in, or a successful silent
    /// refresh).
    func markVerified(_ date: Date) throws
    /// Clears the stored time (e.g. on sign-out).
    func clear() throws
}

/// Keychain-backed implementation.
nonisolated final class KeychainSessionVerificationStore: SessionVerificationStoring, @unchecked Sendable {
    private static let account = "auth.lastVerified"

    private let keychain: KeychainStoring

    init(keychain: KeychainStoring = KeychainStore()) {
        self.keychain = keychain
    }

    func lastVerified() -> Date? {
        guard
            let data = try? keychain.data(account: Self.account, prompt: nil),
            let timeInterval = try? JSONDecoder().decode(TimeInterval.self, from: data)
        else {
            return nil
        }
        return Date(timeIntervalSinceReferenceDate: timeInterval)
    }

    func markVerified(_ date: Date) throws {
        let data = try JSONEncoder().encode(date.timeIntervalSinceReferenceDate)
        try keychain.set(data, account: Self.account, accessControl: nil)
    }

    func clear() throws {
        try keychain.removeItem(account: Self.account)
    }
}

/// In-memory, test/preview-only implementation.
nonisolated final class InMemorySessionVerificationStore: SessionVerificationStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storedDate: Date?

    init(storedDate: Date? = nil) {
        self.storedDate = storedDate
    }

    func lastVerified() -> Date? {
        lock.withLock { storedDate }
    }

    func markVerified(_ date: Date) throws {
        lock.withLock { storedDate = date }
    }

    func clear() throws {
        lock.withLock { storedDate = nil }
    }
}
