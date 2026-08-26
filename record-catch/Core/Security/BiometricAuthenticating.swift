//
//  BiometricAuthenticating.swift
//  record-catch
//
//  Testable abstraction over `LocalAuthentication`'s `LAContext`, so view models never depend on
//  real biometric hardware in unit tests. See ADR-0009 (offline biometric local re-entry).
//
//  This type answers "is biometric evaluation possible right now, and of what kind?" and can run
//  a one-off `LAContext.evaluatePolicy` prompt. It is used for (a) the Settings enable-time
//  enrolment check and (b) the app-lock screen's availability/kind lookup. The actual re-entry
//  *gate* is a Keychain-item read bound to `.biometryCurrentSet` (see `ReentrySecretStoring`) —
//  per OWASP MASVS-AUTH, a bare `evaluatePolicy` call is bypassable via runtime instrumentation,
//  so it must never be the sole gate protecting anything sensitive.
//

import Foundation
import LocalAuthentication

/// Kind of biometry available on this device, decoupled from `LABiometryType` so pure/test code
/// doesn't need to import `LocalAuthentication`.
enum BiometryKind: Sendable, Equatable {
    case none
    case touchID
    case faceID
    case opticID
}

/// Whether biometric evaluation can currently be attempted, and why not if unavailable.
enum BiometricAvailability: Sendable, Equatable {
    case available(BiometryKind)
    case unavailable(BiometricUnavailableReason)
}

enum BiometricUnavailableReason: Sendable, Equatable {
    case noBiometryEnrolled
    case biometryLockedOut
    case passcodeNotSet
    case notSupportedOnDevice
    case other
}

/// Typed errors surfaced by a biometric evaluation attempt (mapped from `LAError`).
enum BiometricError: Error, Sendable, Equatable {
    case userCancelled
    case userFallback
    case systemCancelled
    case biometryNotAvailable
    case biometryNotEnrolled
    case biometryLockedOut
    case authenticationFailed
    case passcodeNotSet
    case other
}

/// Abstraction over `LAContext`. Real evaluation never happens in unit tests — inject
/// `FakeBiometricAuthenticator` instead.
nonisolated protocol BiometricAuthenticating: Sendable {
    /// Checks, without prompting, whether biometric authentication can currently be attempted.
    func biometricAvailability() -> BiometricAvailability

    /// Prompts for biometric authentication with `reason` shown in the system UI.
    /// Throws a `BiometricError` on any failure/cancellation.
    func authenticate(reason: String) async throws
}

/// Real `LAContext`-backed implementation. A fresh `LAContext` is created per evaluation, per
/// Apple guidance not to reuse a context across policy evaluations.
nonisolated final class LABiometricAuthenticator: BiometricAuthenticating, @unchecked Sendable {

    init() {}

    func biometricAvailability() -> BiometricAvailability {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if canEvaluate {
            return .available(BiometryKind(context.biometryType))
        }
        return .unavailable(BiometricUnavailableReason(error))
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        do {
            _ = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let error as LAError {
            throw BiometricError(error)
        } catch {
            throw BiometricError.other
        }
    }
}

extension BiometryKind {
    nonisolated init(_ type: LABiometryType) {
        switch type {
        case .none: self = .none
        case .touchID: self = .touchID
        case .faceID: self = .faceID
        case .opticID: self = .opticID
        @unknown default: self = .none
        }
    }
}

extension BiometricUnavailableReason {
    nonisolated init(_ error: NSError?) {
        guard let laError = error as? LAError else {
            self = .other
            return
        }
        switch laError.code {
        case .biometryNotEnrolled: self = .noBiometryEnrolled
        case .biometryLockout: self = .biometryLockedOut
        case .passcodeNotSet: self = .passcodeNotSet
        case .biometryNotAvailable: self = .notSupportedOnDevice
        default: self = .other
        }
    }
}

extension BiometricError {
    nonisolated init(_ error: LAError) {
        switch error.code {
        case .userCancel: self = .userCancelled
        case .userFallback: self = .userFallback
        case .systemCancel, .appCancel: self = .systemCancelled
        case .biometryNotAvailable: self = .biometryNotAvailable
        case .biometryNotEnrolled: self = .biometryNotEnrolled
        case .biometryLockout: self = .biometryLockedOut
        case .authenticationFailed: self = .authenticationFailed
        case .passcodeNotSet: self = .passcodeNotSet
        default: self = .other
        }
    }
}

/// Deterministic fake for previews/tests — never touches real biometric hardware.
nonisolated final class FakeBiometricAuthenticator: BiometricAuthenticating, @unchecked Sendable {
    private let lock = NSLock()
    private var availability: BiometricAvailability
    private var authenticateResult: Result<Void, BiometricError>
    private(set) var authenticateCallCount = 0

    init(
        availability: BiometricAvailability = .available(.faceID),
        authenticateResult: Result<Void, BiometricError> = .success(())
    ) {
        self.availability = availability
        self.authenticateResult = authenticateResult
    }

    func biometricAvailability() -> BiometricAvailability {
        lock.withLock { availability }
    }

    func authenticate(reason: String) async throws {
        lock.withLock { authenticateCallCount += 1 }
        switch lock.withLock({ authenticateResult }) {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }

    func setAvailability(_ value: BiometricAvailability) {
        lock.withLock { availability = value }
    }

    func setAuthenticateResult(_ value: Result<Void, BiometricError>) {
        lock.withLock { authenticateResult = value }
    }
}
