//
//  EntraConfiguration.swift
//  record-catch
//
//  Build-time Entra External ID configuration resolution (ADR-0022 §6): reads
//  `MMOCRAppConfig.ENTRA_CLIENT_ID` / `ENTRA_TENANT_SUBDOMAIN` from Info.plist, written by the
//  Debug build phase locally and (once real values exist) by the release pipeline per stage.
//
//  Both keys are declared `required: false` in `Config/app-config.schema.json` until a real
//  tenant/app registration exists for each stage. Until then, resolution fails with
//  `EntraConfigurationError.notConfigured` and the app shows the sign-in screen's "not configured"
//  state — it never falls back to another backend or tenant (ADR-0020 §3).
//

import Foundation

/// Mirrors `APIConfiguration`'s `InfoDictionaryProviding` seam so this type is unit-testable
/// without a real `Bundle`.
nonisolated enum EntraConfigurationError: Error, Sendable, Equatable {
    /// `ENTRA_CLIENT_ID` and/or `ENTRA_TENANT_SUBDOMAIN` are missing, blank, or malformed.
    case notConfigured
}

/// Resolves and validates the Entra External ID client ID + tenant subdomain from `Bundle.main`'s
/// Info.plist, using the `MMOCRAppConfig` dictionary defined in ADR-0020 §2.
nonisolated struct EntraConfiguration: Sendable, Equatable {
    /// Application (client) ID of the Entra App registration for this stage — expected to be a
    /// GUID, matching the shape Entra always issues for a client ID.
    let clientID: String
    /// Subdomain of the Microsoft Entra External ID (CIAM) tenant, e.g. "contoso" for
    /// "contoso.ciamlogin.com".
    let tenantSubdomain: String
    /// The Entra External ID scope (API permission) for the Catch Recording Service — e.g.
    /// `"api://<catch-record-service-app-id>/catch-recording.write"` — used by
    /// `MSALNativeAuthenticator.accessToken()` (ADR-0022 addendum, ADR-0025). `nil` until the Entra
    /// tenant team registers the service and supplies a real scope for this stage; a `nil` scope
    /// never prevents sign-in/`restoreSession()` from working, since this value is only consulted
    /// when requesting a *protected-API* token, a separate concern from authentication itself.
    let catchRecordAPIScope: String?

    private static let configKey = "MMOCRAppConfig"
    private static let clientIDKey = "ENTRA_CLIENT_ID"
    private static let tenantSubdomainKey = "ENTRA_TENANT_SUBDOMAIN"
    private static let apiScopeKey = "ENTRA_API_SCOPE"

    /// - Parameter bundle: Defaults to `Bundle.main`; overridable in tests via any
    ///   `InfoDictionaryProviding`.
    /// - Throws: `EntraConfigurationError.notConfigured` if either value is missing, blank, or
    ///   fails the shape checks below.
    init(bundle: InfoDictionaryProviding = Bundle.main) throws {
        guard
            let config = bundle.object(forInfoDictionaryKey: Self.configKey) as? [String: Any],
            let rawClientID = config[Self.clientIDKey] as? String,
            let rawTenantSubdomain = config[Self.tenantSubdomainKey] as? String
        else {
            throw EntraConfigurationError.notConfigured
        }

        let clientID = rawClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let tenantSubdomain = rawTenantSubdomain.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isGUIDShaped(clientID), Self.isValidSubdomain(tenantSubdomain) else {
            throw EntraConfigurationError.notConfigured
        }

        self.clientID = clientID
        self.tenantSubdomain = tenantSubdomain

        // Deliberately tolerant: a missing/blank API scope does not make the whole configuration
        // `.notConfigured` — only `accessToken()` is affected, and it degrades safely to `nil`.
        let rawAPIScope = (config[Self.apiScopeKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.catchRecordAPIScope = (rawAPIScope?.isEmpty == false) ? rawAPIScope : nil
    }

    /// A practical GUID shape check (Entra client IDs are always GUIDs). Pure so it is trivially
    /// unit-testable without constructing a bundle.
    static func isGUIDShaped(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    /// A single DNS hostname label: non-empty, letters/digits/hyphens only, per RFC 1035 — the
    /// shape of the subdomain portion of `<subdomain>.ciamlogin.com`.
    static func isValidSubdomain(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
