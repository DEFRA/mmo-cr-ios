//
//  APIConfiguration.swift
//  record-catch
//
//  Build-time API base URL resolution (ADR-0020 §2): reads Info.plist MMOCRAppConfig.API_BASE_URL,
//  written by the Debug build phase locally and by the release pipeline for shipped builds.
//

import Foundation

/// Minimal seam over "read a value out of an Info.plist-shaped dictionary", satisfied by `Bundle`
/// itself (see the `Bundle` conformance below) and by a lightweight test double — avoids
/// subclassing `Bundle`, which Foundation does not support reliably.
nonisolated protocol InfoDictionaryProviding: Sendable {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: InfoDictionaryProviding {}

/// Resolves and validates the app's reference-data API base URL from `Bundle.main`'s Info.plist
/// using the `MMOCRAppConfig` dictionary defined in ADR-0020 §2.
nonisolated struct APIConfiguration: Sendable {
    let baseURL: URL

    private static let configKey = "MMOCRAppConfig"
    /// Default `MMOCRAppConfig` key — the reference-data service's own base URL. The catch-record
    /// connector (`CatchRecordServicesFactory`, ADR-0025) resolves a *different* key,
    /// `CATCH_RECORD_API_BASE_URL`, via `init(bundle:key:allowsInsecureHTTP:)` below, since the two
    /// services are not (necessarily) hosted at the same address.
    private static let baseURLKey = "API_BASE_URL"

    /// - Parameter bundle: Defaults to `Bundle.main`; overridable in tests via any
    ///   `InfoDictionaryProviding`.
    /// - Throws: `APIError.invalidConfiguration` if `MMOCRAppConfig.API_BASE_URL` is missing, blank,
    ///   unparseable, or not `https` outside `DEBUG` (defence-in-depth, ADR-0020 §2).
    init(bundle: InfoDictionaryProviding = Bundle.main) throws {
        try self.init(bundle: bundle, key: Self.baseURLKey)
    }

    /// Resolves a named `MMOCRAppConfig` key as a base URL — used by `CatchRecordServicesFactory`
    /// to read `CATCH_RECORD_API_BASE_URL` (ADR-0025) with exactly the same validation
    /// (non-blank, parseable, HTTPS outside DEBUG) as the default `API_BASE_URL` key above.
    /// - Parameters:
    ///   - bundle: Defaults to `Bundle.main`; overridable in tests via any `InfoDictionaryProviding`.
    ///   - key: The `MMOCRAppConfig` dictionary key to resolve (e.g. `"API_BASE_URL"` or
    ///     `"CATCH_RECORD_API_BASE_URL"`).
    /// - Throws: `APIError.invalidConfiguration` if the named key is missing, blank, unparseable,
    ///   or not `https` outside `DEBUG`.
    init(bundle: InfoDictionaryProviding = Bundle.main, key: String) throws {
        #if DEBUG
        let allowsInsecureHTTP = true
        #else
        let allowsInsecureHTTP = false
        #endif
        try self.init(bundle: bundle, key: key, allowsInsecureHTTP: allowsInsecureHTTP)
    }

    /// Designated initialiser taking the insecure-HTTP allowance explicitly, so the
    /// Release-configuration rejection path is unit-testable without needing an actual non-DEBUG
    /// build (the public initialisers above always resolve this from `#if DEBUG`).
    init(bundle: InfoDictionaryProviding, allowsInsecureHTTP: Bool) throws {
        try self.init(bundle: bundle, key: Self.baseURLKey, allowsInsecureHTTP: allowsInsecureHTTP)
    }

    /// Fully-explicit designated initialiser: both the `MMOCRAppConfig` key to resolve and the
    /// insecure-HTTP allowance are caller-supplied, so every other initialiser above is a thin
    /// convenience wrapper over this one.
    init(bundle: InfoDictionaryProviding, key: String, allowsInsecureHTTP: Bool) throws {
        guard
            let config = bundle.object(forInfoDictionaryKey: Self.configKey) as? [String: Any],
            let rawValue = config[key] as? String,
            !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let url = URL(string: rawValue),
            let scheme = url.scheme,
            Self.isAcceptableScheme(scheme, allowsInsecureHTTP: allowsInsecureHTTP)
        else {
            throw APIError.invalidConfiguration
        }

        self.baseURL = url
    }

    /// Pure scheme check: `https` is always acceptable; plain `http` is only acceptable when
    /// `allowsInsecureHTTP` is `true` (i.e. a DEBUG build — see ADR-0020 §2).
    static func isAcceptableScheme(_ scheme: String, allowsInsecureHTTP: Bool) -> Bool {
        if scheme.caseInsensitiveCompare("https") == .orderedSame {
            return true
        }
        return allowsInsecureHTTP && scheme.caseInsensitiveCompare("http") == .orderedSame
    }
}
