//
//  ReferenceDataDevSmokeCheck.swift
//  record-catch
//
//  DEBUG-only developer smoke path (see ADR-0018 §"Implementation Steps" step 7). Performs one
//  real call against a locally-running backend and reports the decoded vessel count. This is
//  **not** part of the automated `record-catchTests` suite — it requires a live backend at
//  `http://localhost:3002` and is invoked manually (e.g. via Xcode's "Run Code Snippet" tooling,
//  or a manual call from the debugger) while developing against the real API. It must never be
//  called from a test that runs as part of the default `fastlane test`/CI lane.
//

import Foundation

#if DEBUG
/// Performs one real call to `fetchVessels()` against the app's configured (Debug) base URL and
/// returns a short human-readable summary. Throws whatever `ReferenceDataFetching` throws (e.g.
/// `APIError.unauthorized` if `REFERENCE_DATA_API_TOKEN` isn't set and the backend requires it)
/// rather than swallowing it, so a developer sees the real failure.
nonisolated func verifyReferenceDataConnectivity() async throws -> String {
    let configuration = try APIConfiguration()
    let client = RemoteReferenceDataClient(
        httpClient: URLSessionHTTPClient(),
        configuration: configuration,
        tokenProvider: EnvironmentTokenProvider()
    )
    let vessels = try await client.fetchVessels()
    return "Fetched \(vessels.count) vessel(s) from \(configuration.baseURL.absoluteString)"
}
#endif
