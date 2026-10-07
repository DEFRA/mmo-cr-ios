#if BACKEND_HEALTH_CHECK
import XCTest
@testable import record_catch

private struct StubTransport: BackendHealthTransport {
    enum Behaviour {
        case success(statusCode: Int, body: Data)
        case failure(Error)
    }

    let behaviour: Behaviour
    let onRequest: (@Sendable (URLRequest) -> Void)?

    init(behaviour: Behaviour, onRequest: (@Sendable (URLRequest) -> Void)? = nil) {
        self.behaviour = behaviour
        self.onRequest = onRequest
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        onRequest?(request)
        switch behaviour {
        case .success(let statusCode, let body):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (body, response)
        case .failure(let error):
            throw error
        }
    }
}

private struct TransportError: Error {}

final class BackendHealthCheckerTests: XCTestCase {

    private let validInfo: [String: Any] = [
        "MMOCRAppConfig": ["API_BASE_URL": "https://example.gov.uk"]
    ]

    private func jsonBody(_ status: String) -> Data {
        Data("{\"status\":\"\(status)\"}".utf8)
    }

    func test_check_returnsHealthy_for200WithOkStatus() async {
        let transport = StubTransport(behaviour: .success(statusCode: 200, body: jsonBody("ok")))

        let result = await BackendHealthChecker.check(infoDictionary: validInfo, transport: transport)

        XCTAssertEqual(result, .healthy)
    }

    func test_check_returnsConnectivityError_for200WithOtherStatus() async {
        let transport = StubTransport(behaviour: .success(statusCode: 200, body: jsonBody("degraded")))

        let result = await BackendHealthChecker.check(infoDictionary: validInfo, transport: transport)

        XCTAssertEqual(result, .connectivityError)
    }

    func test_check_returnsConnectivityError_forNon200Response() async {
        let transport = StubTransport(behaviour: .success(statusCode: 503, body: jsonBody("ok")))

        let result = await BackendHealthChecker.check(infoDictionary: validInfo, transport: transport)

        XCTAssertEqual(result, .connectivityError)
    }

    func test_check_returnsConnectivityError_forMalformedBody() async {
        let transport = StubTransport(behaviour: .success(statusCode: 200, body: Data("not json".utf8)))

        let result = await BackendHealthChecker.check(infoDictionary: validInfo, transport: transport)

        XCTAssertEqual(result, .connectivityError)
    }

    func test_check_returnsConnectivityError_whenTransportThrows() async {
        let transport = StubTransport(behaviour: .failure(TransportError()))

        let result = await BackendHealthChecker.check(infoDictionary: validInfo, transport: transport)

        XCTAssertEqual(result, .connectivityError)
    }

    func test_check_returnsConnectivityError_whenBaseURLMissing() async {
        let transport = StubTransport(behaviour: .success(statusCode: 200, body: jsonBody("ok")))

        let result = await BackendHealthChecker.check(infoDictionary: [:], transport: transport)

        XCTAssertEqual(result, .connectivityError)
    }

    func test_check_returnsConnectivityError_whenBaseURLNotHTTPS() async {
        let info: [String: Any] = ["MMOCRAppConfig": ["API_BASE_URL": "http://example.gov.uk"]]
        let transport = StubTransport(behaviour: .success(statusCode: 200, body: jsonBody("ok")))

        let result = await BackendHealthChecker.check(infoDictionary: info, transport: transport)

        XCTAssertEqual(result, .connectivityError)
    }

    func test_check_buildsHealthEndpointURL_fromBaseURL() async {
        let requestedURL = ExpectedURLBox()
        let transport = StubTransport(
            behaviour: .success(statusCode: 200, body: jsonBody("ok")),
            onRequest: { requestedURL.url = $0.url }
        )

        _ = await BackendHealthChecker.check(infoDictionary: validInfo, transport: transport)

        XCTAssertEqual(requestedURL.url, URL(string: "https://example.gov.uk/reference-data-service/health"))
    }

    func test_check_sendsGETRequest() async {
        let requestedMethod = ExpectedMethodBox()
        let transport = StubTransport(
            behaviour: .success(statusCode: 200, body: jsonBody("ok")),
            onRequest: { requestedMethod.method = $0.httpMethod }
        )

        _ = await BackendHealthChecker.check(infoDictionary: validInfo, transport: transport)

        XCTAssertEqual(requestedMethod.method, "GET")
    }

    // MARK: - healthCheckURL(from:)

    func test_healthCheckURL_nil_whenAPIBaseURLMissing() {
        XCTAssertNil(BackendHealthChecker.healthCheckURL(from: [:]))
    }

    func test_healthCheckURL_nil_whenSchemeNotHTTPS() {
        let info: [String: Any] = ["MMOCRAppConfig": ["API_BASE_URL": "http://example.gov.uk"]]
        XCTAssertNil(BackendHealthChecker.healthCheckURL(from: info))
    }

    func test_healthCheckURL_nil_whenHostEmpty() {
        let info: [String: Any] = ["MMOCRAppConfig": ["API_BASE_URL": "https:///path"]]
        XCTAssertNil(BackendHealthChecker.healthCheckURL(from: info))
    }

    func test_healthCheckURL_nil_whenCredentialsEmbedded() {
        let info: [String: Any] = ["MMOCRAppConfig": ["API_BASE_URL": "https://user:pass@example.gov.uk"]]
        XCTAssertNil(BackendHealthChecker.healthCheckURL(from: info))
    }

    func test_healthCheckURL_appendsHealthPath_forValidBaseURL() {
        let url = BackendHealthChecker.healthCheckURL(from: validInfo)
        XCTAssertEqual(url, URL(string: "https://example.gov.uk/reference-data-service/health"))
    }
}

/// Simple reference box so the `onRequest` closure can capture the requested URL for assertion.
private final class ExpectedURLBox: @unchecked Sendable {
    var url: URL?
}

/// Simple reference box so the `onRequest` closure can capture the requested HTTP method.
private final class ExpectedMethodBox: @unchecked Sendable {
    var method: String?
}
#endif
