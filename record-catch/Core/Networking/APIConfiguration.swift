//
//  APIConfiguration.swift
//  record-catch
//
//  Build-time API base URL resolution (see ADR-0018 §3). Reads the `APIBaseURL` Info.plist key,
//  itself substituted from the `API_BASE_URL` .xcconfig build setting per-configuration
//  (Config/Debug.xcconfig, Config/Release.xcconfig) — the frozen "Option B" build-time
//  configuration approach in .github/instructions/ci-cd.instructions.md.
//

import Foundation

/// Minimal seam over "read a value out of an Info.plist-shaped dictionary", satisfied by `Bundle`
/// itself (see the `Bundle` conformance below) and by a lightweight test double — avoids
/// subclassing `Bundle`, which Foundation does not support reliably.
nonisolated protocol InfoDictionaryProviding: Sendable {
    func object(forInfoDictionaryKey key: String) -> Any?
}

extension Bundle: InfoDictionaryProviding {}

/// Resolves and validates the app's reference-data API base URL from `Bundle.main`'s Info.plist.
nonisolated struct APIConfiguration: Sendable {
    let baseURL: URL

    /// - Parameter bundle: Defaults to `Bundle.main`; overridable in tests via any
    ///   `InfoDictionaryProviding`.
    /// - Throws: `APIError.invalidConfiguration` if `APIBaseURL` is missing, blank, fails to parse
    ///   as a URL, or (outside a `DEBUG` build) is not `https`. The non-HTTPS rejection is
    ///   defence-in-depth: even if a Release `.xcconfig` were ever misconfigured with an `http://`
    ///   value, a Release/App-Store binary can never accept it (see ADR-0018 §3).
    init(bundle: InfoDictionaryProviding = Bundle.main) throws {
        #if DEBUG
        let allowsInsecureHTTP = true
        #else
        let allowsInsecureHTTP = false
        #endif
        try self.init(bundle: bundle, allowsInsecureHTTP: allowsInsecureHTTP)
    }

    /// Designated initialiser taking the insecure-HTTP allowance explicitly, so the
    /// Release-configuration rejection path is unit-testable without needing an actual non-DEBUG
    /// build (the public `init(bundle:)` above always resolves this from `#if DEBUG`).
    init(bundle: InfoDictionaryProviding, allowsInsecureHTTP: Bool) throws {
        guard
            let rawValue = bundle.object(forInfoDictionaryKey: "APIBaseURL") as? String,
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
    /// `allowsInsecureHTTP` is `true` (i.e. a DEBUG build — see ADR-0018 §3).
    static func isAcceptableScheme(_ scheme: String, allowsInsecureHTTP: Bool) -> Bool {
        if scheme.caseInsensitiveCompare("https") == .orderedSame {
            return true
        }
        return allowsInsecureHTTP && scheme.caseInsensitiveCompare("http") == .orderedSame
    }
}
