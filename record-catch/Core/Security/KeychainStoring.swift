//
//  KeychainStoring.swift
//  record-catch
//
//  Minimal SecItem CRUD abstraction (see ADR-0009 and security.instructions.md). No secret
//  values are ever logged here — only status codes, via `OSLog` with `.private` redaction where
//  callers choose to log at all.
//

import Foundation
import LocalAuthentication
import Security

enum KeychainError: Error, Sendable, Equatable {
    case unhandledStatus(OSStatus)
    case unexpectedData
    case accessControlCreationFailed
}

/// Abstraction over Keychain `SecItem` storage, testable via `InMemoryKeychainStore`.
nonisolated protocol KeychainStoring: Sendable {
    /// Stores `data` under `account`, replacing any existing item. `accessControl`, if provided,
    /// gates retrieval (e.g. biometric protection); `nil` stores a plain, non-gated item.
    func set(_ data: Data, account: String, accessControl: SecAccessControl?) throws

    /// Reads the data stored under `account`. Returns `nil` if no item exists. `prompt`, if
    /// provided, is shown as the biometric prompt reason when the item is access-controlled.
    /// Throws `BiometricError` when a biometric-gated read is cancelled/fails, or
    /// `KeychainError` for any other underlying failure.
    func data(account: String, prompt: String?) throws -> Data?

    /// Removes any item stored under `account`. A no-op if none exists.
    func removeItem(account: String) throws

    /// Cheaply reports whether an item exists under `account`, without ever triggering a
    /// biometric prompt (used to check "is a re-entry secret provisioned?").
    func itemExists(account: String) -> Bool
}

/// Real `SecItem`-backed implementation, scoped to this app's own Keychain service namespace.
nonisolated final class KeychainStore: KeychainStoring, @unchecked Sendable {
    private let service: String

    init(service: String = "uk.gov.defra.record-catch") {
        self.service = service
    }

    func set(_ data: Data, account: String, accessControl: SecAccessControl?) throws {
        // Replace-semantics: delete any existing item first (SecItemUpdate cannot change the
        // access-control flags of an existing item, so add-fresh is simpler and correct here).
        try? removeItem(account: account)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        if let accessControl {
            query[kSecAttrAccessControl as String] = accessControl
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandledStatus(status) }
    }

    func data(account: String, prompt: String?) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let prompt {
            // `kSecUseOperationPrompt` is deprecated in favour of an `LAContext` carrying
            // `localizedReason` (Apple, *Accessing Keychain Items with Face ID or Touch ID*).
            let context = LAContext()
            context.localizedReason = prompt
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            return nil
        case errSecUserCanceled:
            throw BiometricError.userCancelled
        default:
            // Biometric failure/lockout on an access-controlled item and other Keychain
            // failures both surface as non-success OSStatus codes here; treated uniformly as an
            // authentication failure for the caller's retry/fallback decision (see
            // `BiometricReentryPolicy`). Real-device manual QA (ADR-0009) verifies this in
            // practice, since the exact statuses cannot be exercised without real hardware.
            throw BiometricError.authenticationFailed
        }
    }

    func removeItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    func itemExists(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
            kSecReturnData as String: false
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // `errSecInteractionNotAllowed` means the item exists but is access-controlled and we
        // explicitly skipped the UI — still "exists" for our purposes.
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }
}

/// In-memory, test/preview-only implementation — never touches the real Keychain.
nonisolated final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    /// When set, the next `data(account:prompt:)` call for a matching account throws this
    /// instead of returning the stored value — simulates biometric cancel/failure/lockout.
    var readErrorsByAccount: [String: Error] = [:]

    init() {}

    func set(_ data: Data, account: String, accessControl: SecAccessControl?) throws {
        lock.withLock { storage[account] = data }
    }

    func data(account: String, prompt: String?) throws -> Data? {
        if let error = lock.withLock({ readErrorsByAccount[account] }) {
            throw error
        }
        return lock.withLock { storage[account] }
    }

    func removeItem(account: String) throws {
        lock.withLock { _ = storage.removeValue(forKey: account) }
    }

    func itemExists(account: String) -> Bool {
        lock.withLock { storage[account] != nil }
    }
}
