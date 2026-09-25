//
//  URLSessionHTTPClientTests.swift
//  record-catchTests
//
//  URLProtocol-based test for the concrete URLSessionHTTPClient, so it isn't a coverage hole
//  behind the HTTPPerforming seam (see ADR-0018 §2, testing.instructions.md).
//

import XCTest
@testable import record_catch

/// Intercepts requests made through a `URLSession` configured with this protocol registered,
/// returning a canned response/error instead of touching the real network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseProvider: ((URLRequest) -> (HTTPURLResponse, Data)?)?
    /// A response provider that returns a plain (non-HTTP) `URLResponse`, used to test
    /// `URLSessionHTTPClient.send(_:)`'s fallback when the underlying transport doesn't produce
    /// an `HTTPURLResponse` (see `HTTPPerforming.swift`).
    nonisolated(unsafe) static var plainResponseProvider: ((URLRequest) -> URLResponse)?
    nonisolated(unsafe) static var errorProvider: ((URLRequest) -> Error?)?

    static override func canInit(with request: URLRequest) -> Bool { true }
    static override func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.errorProvider?(request) {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let plainResponse = Self.plainResponseProvider?(request) {
            client?.urlProtocol(self, didReceive: plainResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        guard let (response, data) = Self.responseProvider?(request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // Intentionally empty: the canned response above completes synchronously within
        // `startLoading()`, so there is no in-flight work to cancel.
    }
}

final class URLSessionHTTPClientTests: XCTestCase {

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override func tearDown() {
        StubURLProtocol.responseProvider = nil
        StubURLProtocol.plainResponseProvider = nil
        StubURLProtocol.errorProvider = nil
        super.tearDown()
    }

    func test_init_withDefaultSession_constructsSuccessfully() {
        // Exercises `makeDefaultSession()` (the 15s-timeout, waitsForConnectivity=false
        // configuration), which is otherwise only reached via the default parameter and never
        // invoked by the other tests in this file (they always inject a stub-protocol session).
        let sut = URLSessionHTTPClient()

        XCTAssertNotNil(sut)
    }

    func test_send_throwsTransportCodeMinusOne_whenResponseIsNotHTTPURLResponse() async {
        let url = URL(string: "https://example.invalid/resource")!
        StubURLProtocol.plainResponseProvider = { request in
            URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        }
        let sut = URLSessionHTTPClient(session: makeSession())

        do {
            _ = try await sut.send(URLRequest(url: url))
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .transport(code: -1))
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_send_returnsDataAndHTTPURLResponse_onSuccess() async throws {
        let url = URL(string: "https://example.invalid/resource")!
        let expectedData = Data("{\"ok\":true}".utf8)
        StubURLProtocol.responseProvider = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, expectedData)
        }
        let sut = URLSessionHTTPClient(session: makeSession())

        let (data, response) = try await sut.send(URLRequest(url: url))

        XCTAssertEqual(data, expectedData)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_send_propagatesTransportError() async {
        let url = URL(string: "https://example.invalid/resource")!
        StubURLProtocol.errorProvider = { _ in URLError(.timedOut) }
        let sut = URLSessionHTTPClient(session: makeSession())

        do {
            _ = try await sut.send(URLRequest(url: url))
            XCTFail("Expected an error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        } catch {
            XCTFail("Expected URLError, got \(error)")
        }
    }
}
