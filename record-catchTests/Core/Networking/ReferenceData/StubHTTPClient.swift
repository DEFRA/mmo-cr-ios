//
//  StubHTTPClient.swift
//  record-catchTests
//
//  Deterministic HTTPPerforming fake for connector behaviour tests — no real network. See
//  testing.instructions.md ("no real network in unit tests").
//

import Foundation
@testable import record_catch

final class StubHTTPClient: HTTPPerforming, @unchecked Sendable {
    /// The response (or error) to return from the next `send(_:)` call.
    var result: Result<(Data, HTTPURLResponse), Error>
    /// Captures every request passed to `send(_:)`, for assertions on headers/URL.
    private(set) var receivedRequests: [URLRequest] = []

    init(result: Result<(Data, HTTPURLResponse), Error>) {
        self.result = result
    }

    /// Convenience for a successful JSON response.
    static func success(statusCode: Int, jsonData: Data, url: URL = URL(string: "https://example.invalid")!) -> StubHTTPClient {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return StubHTTPClient(result: .success((jsonData, response)))
    }

    /// Convenience for a response carrying only a status code (no body needed).
    static func statusOnly(_ statusCode: Int, url: URL = URL(string: "https://example.invalid")!) -> StubHTTPClient {
        success(statusCode: statusCode, jsonData: Data(), url: url)
    }

    /// Convenience for a transport-level failure (e.g. a `URLError`).
    static func failure(_ error: Error) -> StubHTTPClient {
        StubHTTPClient(result: .failure(error))
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        receivedRequests.append(request)
        return try result.get()
    }
}
