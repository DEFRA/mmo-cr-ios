//
//  EnvironmentTokenProviderTests.swift
//  record-catchTests
//
//  Covers the DEBUG-only token seam (see ADR-0018 §5). Security-critical path — 100% coverage
//  target per testing.instructions.md.
//

import XCTest
@testable import record_catch

final class EnvironmentTokenProviderTests: XCTestCase {

    func test_bearerToken_returnsTrimmedValue_whenEnvironmentVariableSet() async throws {
        let sut = EnvironmentTokenProvider(environment: ["REFERENCE_DATA_API_TOKEN": "  my-token  "])

        let token = try await sut.bearerToken()

        XCTAssertEqual(token, "my-token")
    }

    func test_bearerToken_returnsNil_whenEnvironmentVariableUnset() async throws {
        let sut = EnvironmentTokenProvider(environment: [:])

        let token = try await sut.bearerToken()

        XCTAssertNil(token)
    }

    func test_bearerToken_returnsNil_whenEnvironmentVariableBlank() async throws {
        let sut = EnvironmentTokenProvider(environment: ["REFERENCE_DATA_API_TOKEN": "   "])

        let token = try await sut.bearerToken()

        XCTAssertNil(token)
    }
}

/// Covers the production placeholder `AuthTokenProviding` (see that type's doc comment and
/// ADR-0024 "Known gap — production bearer token"). Security-critical path — 100% coverage target
/// per testing.instructions.md.
final class NilAuthTokenProviderTests: XCTestCase {

    func test_bearerToken_alwaysReturnsNil() async throws {
        let sut = NilAuthTokenProvider()

        let token = try await sut.bearerToken()

        XCTAssertNil(token)
    }
}
