//
//  ReentrySecretStore.swift
//  record-catch
//
//  The biometric-gated local re-entry secret (ADR-0009 §1). Stores an opaque, locally-generated
//  value under `.biometryCurrentSet` — its value is never used for anything; only its
//  biometric-gated *retrievability* is meaningful (proves "same enrolled biometrics as when
//  provisioned"). This is **not** a backend credential — there is no real backend authentication
//  in this app yet.
//

import Foundation
import Security

nonisolated protocol ReentrySecretStoring: Sendable {
    /// Whether a re-entry secret is currently provisioned. Never triggers a biometric prompt.
    func secretExists() -> Bool
    /// Generates and stores a new re-entry secret, protected by the current biometric enrolment
    /// (`.biometryCurrentSet` — invalidated automatically if enrolment changes).
    func provisionSecret() throws
    /// Attempts a biometric-gated read of the secret. Success means re-entry is granted; throws
    /// `BiometricError` on cancellation/failure/lockout, per `KeychainStoring.data`.
    func verifyReentry(reason: String) async throws
    /// Removes the stored secret (e.g. the user opts out, or after an enrolment change).
    func clearSecret() throws
}

nonisolated final class KeychainReentrySecretStore: ReentrySecretStoring, @unchecked Sendable {
    private static let account = "reentry.secret"
    private static let secretByteCount = 32

    private let keychain: KeychainStoring

    init(keychain: KeychainStoring = KeychainStore()) {
        self.keychain = keychain
    }

    func secretExists() -> Bool {
        keychain.itemExists(account: Self.account)
    }

    func provisionSecret() throws {
        var bytes = [UInt8](repeating: 0, count: Self.secretByteCount)
        let randomStatus = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard randomStatus == errSecSuccess else {
            throw KeychainError.unhandledStatus(randomStatus)
        }

        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &accessControlError
        ) else {
            throw KeychainError.accessControlCreationFailed
        }

        try keychain.set(Data(bytes), account: Self.account, accessControl: accessControl)
    }

    func verifyReentry(reason: String) async throws {
        // `SecItemCopyMatching` on an access-controlled item blocks for the duration of the
        // biometric prompt, so it is dispatched off the calling (main) actor.
        let keychain = keychain
        try await Task.detached(priority: .userInitiated) {
            _ = try keychain.data(account: Self.account, prompt: reason)
        }.value
    }

    func clearSecret() throws {
        try keychain.removeItem(account: Self.account)
    }
}

/// Deterministic fake for previews/tests — never touches the real Keychain or biometric hardware.
nonisolated final class InMemoryReentrySecretStore: ReentrySecretStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var exists: Bool
    /// Error to throw from `verifyReentry`, if any — lets tests simulate cancel/failure/lockout
    /// without real hardware. `nil` means "succeed".
    private var verifyError: Error?

    init(exists: Bool = false, verifyError: Error? = nil) {
        self.exists = exists
        self.verifyError = verifyError
    }

    func secretExists() -> Bool {
        lock.withLock { exists }
    }

    func provisionSecret() throws {
        lock.withLock { exists = true }
    }

    func verifyReentry(reason: String) async throws {
        if let error = lock.withLock({ verifyError }) {
            throw error
        }
        guard lock.withLock({ exists }) else {
            throw KeychainError.unexpectedData
        }
    }

    func clearSecret() throws {
        lock.withLock { exists = false }
    }

    func setVerifyError(_ error: Error?) {
        lock.withLock { verifyError = error }
    }
}
