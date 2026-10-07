//
//  BackendHealthChecker.swift
//  record-catch
//
//  Temporary, local-build-only backend connectivity check (ADR-0014 follow-up covers the real
//  startup `AppConfiguration`). Entirely compiled out unless `BACKEND_HEALTH_CHECK` is set — see
//  Config/Local.xcconfig.example — so it can never ship in a CI/release build.
//

#if BACKEND_HEALTH_CHECK
import Foundation
import OSLog

/// Outcome of a single backend connectivity check.
enum BackendHealthStatus: Equatable, Sendable {
    case healthy
    case connectivityError
}

/// Transport seam so `BackendHealthChecker` is unit-testable without a real network call.
nonisolated protocol BackendHealthTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Real transport: ephemeral session (no shared cookie/cache state), caching disabled, 10s timeout.
nonisolated struct URLSessionBackendHealthTransport: BackendHealthTransport {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        session = URLSession(configuration: configuration)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// Calls `<API_BASE_URL>/reference-data-service/health` and reports whether the backend is
/// reachable. Healthy only on HTTP 200 with a decoded body of `status == "ok"` — every other
/// outcome (missing/invalid base URL, non-200, unexpected status, malformed body, transport
/// failure) maps to `.connectivityError`, so this can never be mistaken for a real uptime signal.
enum BackendHealthChecker {

    private struct HealthResponse: Decodable {
        let status: String
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "uk.gov.defra.catchrecording",
        category: "BackendHealthCheck"
    )

    /// - Parameters:
    ///   - infoDictionary: Injectable for tests; defaults to the running app's own Info.plist.
    ///   - transport: Injectable for tests; defaults to a fresh ephemeral `URLSession`.
    static func check(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
        transport: some BackendHealthTransport = URLSessionBackendHealthTransport()
    ) async -> BackendHealthStatus {
        guard let url = healthCheckURL(from: infoDictionary) else {
            logger.error("Backend health check skipped: missing or invalid API_BASE_URL")
            return .connectivityError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await transport.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.error("Backend health check failed: non-200 response")
                return .connectivityError
            }
            guard try JSONDecoder().decode(HealthResponse.self, from: data).status == "ok" else {
                logger.error("Backend health check failed: unexpected response body")
                return .connectivityError
            }
            return .healthy
        } catch {
            // Never log the error description here: it can embed the request URL/host.
            logger.error("Backend health check failed: transport error")
            return .connectivityError
        }
    }

    /// Builds `<API_BASE_URL>/reference-data-service/health` from `MMOCRAppConfig.API_BASE_URL`,
    /// accepting only an `https` base URL with a non-empty host and no embedded credentials.
    static func healthCheckURL(from infoDictionary: [String: Any]?) -> URL? {
        guard
            let config = infoDictionary?["MMOCRAppConfig"] as? [String: Any],
            let baseURLString = config["API_BASE_URL"] as? String,
            let components = URLComponents(string: baseURLString),
            components.scheme == "https",
            let host = components.host, !host.isEmpty,
            components.user == nil,
            components.password == nil,
            let baseURL = components.url
        else {
            return nil
        }

        return baseURL.appendingPathComponent("reference-data-service/health")
    }
}
#endif
