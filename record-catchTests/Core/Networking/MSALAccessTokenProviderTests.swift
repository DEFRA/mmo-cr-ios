//
//  MSALAccessTokenProviderTests.swift
//  record-catchTests
//
//  Covers `MSALAccessTokenProvider` — the `AuthTokenProviding` bridge the Catch Recording Service
//  connector resolves bearer tokens through (ADR-0025). Uses `FakeAuthenticator` so no real MSAL
//  session or network is needed (testing.instructions.md).
//

import XCTest
@testable import record_catch

@MainActor
final class MSALAccessTokenProviderTests: XCTestCase {

    func test_bearerToken_returnsTheAuthenticatorsAccessToken_whenSignedIn() async throws {
        let authenticator = FakeAuthenticator(hasCachedAccount: true, accessTokenResult: "token-123")
        let sut = MSALAccessTokenProvider(authenticator: { authenticator })

        let token = try await sut.bearerToken()

        XCTAssertEqual(token, "token-123")
        XCTAssertEqual(authenticator.accessTokenCallCount, 1)
    }

    func test_bearerToken_returnsNil_whenNotSignedIn() async throws {
        let authenticator = FakeAuthenticator(hasCachedAccount: false)
        let sut = MSALAccessTokenProvider(authenticator: { authenticator })

        let token = try await sut.bearerToken()

        XCTAssertNil(token)
    }

    func test_bearerToken_resolvesFreshEveryCall_ratherThanCaching() async throws {
        let authenticator = FakeAuthenticator(hasCachedAccount: true, accessTokenResult: "first")
        let sut = MSALAccessTokenProvider(authenticator: { authenticator })

        _ = try await sut.bearerToken()
        authenticator.accessTokenResult = "second"
        let second = try await sut.bearerToken()

        XCTAssertEqual(second, "second")
        XCTAssertEqual(authenticator.accessTokenCallCount, 2)
    }
}
