//
//  APIConfigurationTests.swift
//  record-catchTests
//
//  Covers APIConfiguration's Info.plist resolution and scheme validation (see ADR-0018 §3).
//  100% coverage target — this is a security-relevant / error-handling path.
//

import XCTest
@testable import record_catch

final class APIConfigurationTests: XCTestCase {

    /// In-memory `InfoDictionaryProviding` double so tests don't depend on any real bundle's
    /// Info.plist (avoids subclassing `Bundle`, which Foundation does not support reliably).
    private struct FakeInfoDictionary: InfoDictionaryProviding {
        var values: [String: Any] = [:]
        func object(forInfoDictionaryKey key: String) -> Any? {
            values[key]
        }
    }

    private func makeBundle(apiBaseURL: Any?) -> FakeInfoDictionary {
        var bundle = FakeInfoDictionary()
        if let apiBaseURL {
            bundle.values["APIBaseURL"] = apiBaseURL
        }
        return bundle
    }

    func test_init_succeeds_withValidHTTPSURL() throws {
        let bundle = makeBundle(apiBaseURL: "https://api.example.com")

        let configuration = try APIConfiguration(bundle: bundle, allowsInsecureHTTP: false)

        XCTAssertEqual(configuration.baseURL.absoluteString, "https://api.example.com")
    }

    func test_init_succeeds_withHTTPURL_whenInsecureHTTPAllowed() throws {
        let bundle = makeBundle(apiBaseURL: "http://localhost:3002")

        let configuration = try APIConfiguration(bundle: bundle, allowsInsecureHTTP: true)

        XCTAssertEqual(configuration.baseURL.absoluteString, "http://localhost:3002")
    }

    func test_init_throwsInvalidConfiguration_whenKeyMissing() {
        let bundle = makeBundle(apiBaseURL: nil)

        XCTAssertThrowsError(try APIConfiguration(bundle: bundle, allowsInsecureHTTP: true)) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
    }

    func test_init_throwsInvalidConfiguration_whenValueBlank() {
        let bundle = makeBundle(apiBaseURL: "   ")

        XCTAssertThrowsError(try APIConfiguration(bundle: bundle, allowsInsecureHTTP: true)) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
    }

    func test_init_throwsInvalidConfiguration_whenValueMalformed() {
        // A string with only whitespace/control characters fails `URL(string:)`.
        let bundle = makeBundle(apiBaseURL: "\n\t")

        XCTAssertThrowsError(try APIConfiguration(bundle: bundle, allowsInsecureHTTP: true)) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
    }

    func test_init_throwsInvalidConfiguration_forHTTPURL_whenInsecureHTTPNotAllowed() {
        // Simulates a non-DEBUG (Release) build encountering a plain-HTTP base URL.
        let bundle = makeBundle(apiBaseURL: "http://localhost:3002")

        XCTAssertThrowsError(try APIConfiguration(bundle: bundle, allowsInsecureHTTP: false)) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
    }

    func test_isAcceptableScheme_alwaysAcceptsHTTPS() {
        XCTAssertTrue(APIConfiguration.isAcceptableScheme("https", allowsInsecureHTTP: false))
        XCTAssertTrue(APIConfiguration.isAcceptableScheme("https", allowsInsecureHTTP: true))
        XCTAssertTrue(APIConfiguration.isAcceptableScheme("HTTPS", allowsInsecureHTTP: false))
    }

    func test_isAcceptableScheme_rejectsHTTP_whenInsecureHTTPNotAllowed() {
        XCTAssertFalse(APIConfiguration.isAcceptableScheme("http", allowsInsecureHTTP: false))
    }

    func test_isAcceptableScheme_acceptsHTTP_whenInsecureHTTPAllowed() {
        XCTAssertTrue(APIConfiguration.isAcceptableScheme("http", allowsInsecureHTTP: true))
    }

    // MARK: init(bundle:) convenience initialiser — resolves `allowsInsecureHTTP` from `#if DEBUG`.
    // The test target itself always compiles DEBUG, so `allowsInsecureHTTP` resolves `true` here;
    // this still exercises the convenience initialiser's forwarding to the designated one (see
    // `init(bundle:allowsInsecureHTTP:)` above), which is otherwise never called in this suite.

    func test_init_bundleOnly_succeeds_withHTTPURL() throws {
        let bundle = makeBundle(apiBaseURL: "http://localhost:3002")

        let configuration = try APIConfiguration(bundle: bundle)

        XCTAssertEqual(configuration.baseURL.absoluteString, "http://localhost:3002")
    }

    func test_init_bundleOnly_throwsInvalidConfiguration_whenKeyMissing() {
        let bundle = makeBundle(apiBaseURL: nil)

        XCTAssertThrowsError(try APIConfiguration(bundle: bundle)) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
    }
}
