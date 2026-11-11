//
//  FailingReferenceDataClientTests.swift
//  record-catchTests
//
//  Covers `FailingReferenceDataClient` — the always-throwing `ReferenceDataFetching` double used
//  by `ReferenceDataSyncCoordinator.make(store:connectivityMonitor:)` when this launch's
//  `APIConfiguration()` itself throws (a misconfigured `Info.plist`, see ADR-0020 §2). Asserts
//  every method throws `APIError.invalidConfiguration` uniformly, so a bad build configuration
//  surfaces `SyncErrorBanner` instead of crashing app launch.
//

import XCTest
@testable import record_catch

final class FailingReferenceDataClientTests: XCTestCase {

    private let sut = FailingReferenceDataClient()

    func test_fetchVessels_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchVessels() }
    }

    func test_fetchVessel_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchVessel(id: "1") }
    }

    func test_fetchSpecies_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchSpecies() }
    }

    func test_fetchSpeciesItem_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchSpecies(id: "1") }
    }

    func test_fetchPorts_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchPorts() }
    }

    func test_fetchPort_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchPort(id: "1") }
    }

    func test_fetchGears_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchGears() }
    }

    func test_fetchManifest_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchManifest() }
    }

    func test_fetchBlob_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.fetchBlob(urlString: "map-land") }
    }

    func test_checkHealth_throwsInvalidConfiguration() async {
        await assertThrowsInvalidConfiguration { try await self.sut.checkHealth() }
    }

    /// Shared assertion: every `FailingReferenceDataClient` method must throw exactly
    /// `APIError.invalidConfiguration` — never succeed, never a different error.
    private func assertThrowsInvalidConfiguration<Item>(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: @escaping () async throws -> Item
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected APIError.invalidConfiguration", file: file, line: line)
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidConfiguration, file: file, line: line)
        } catch {
            XCTFail("Expected APIError, got \(error)", file: file, line: line)
        }
    }
}
