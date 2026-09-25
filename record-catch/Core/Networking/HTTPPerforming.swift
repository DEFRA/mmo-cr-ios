//
//  HTTPPerforming.swift
//  record-catch
//
//  Minimal HTTP transport seam (see ADR-0018). Kept deliberately narrow — send a request, get
//  back data + the HTTP response — so it's trivially fakeable in tests (`StubHTTPClient`) without
//  a real network, per testing.instructions.md ("no real network in unit tests").
//

import Foundation

/// Abstraction over performing a single HTTP request. The only production implementation is
/// `URLSessionHTTPClient`; tests use an in-memory fake.
nonisolated protocol HTTPPerforming: Sendable {
    /// Sends `request` and returns the raw response body and headers/status. Throws the
    /// underlying transport error (e.g. `URLError`) on failure — mapping into `APIError` is the
    /// caller's responsibility (see `ReferenceDataClient`), keeping this seam a pure transport.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Real `URLSession`-backed implementation. Per Apple's TN3151, `URLSession` is the recommended
/// HTTP client and has first-class `async`/`await` support.
nonisolated final class URLSessionHTTPClient: HTTPPerforming {
    private let session: URLSession

    /// - Parameter session: Defaults to a session configured with a 15s per-request timeout and
    ///   `waitsForConnectivity = false`, so a request fails fast with `URLError.notConnectedToInternet`
    ///   when offline rather than hanging indefinitely — consistent with the app remaining
    ///   responsive without connectivity (see ADR-0018 §"Consequences").
    init(session: URLSession = URLSessionHTTPClient.makeDefaultSession()) {
        self.session = session
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            // A non-HTTP response (e.g. a file:// or custom scheme) is not expected for this
            // connector; surface it the same way an unmapped transport failure would.
            throw APIError.transport(code: -1)
        }
        return (data, httpResponse)
    }
}
