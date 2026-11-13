//
//  CatchRecordServicesFactoryTests.swift
//  record-catchTests
//
//  Covers `CatchRecordServicesFactory.make` (ADR-0025): the test bundle's `Info.plist` has no
//  `CATCH_RECORD_API_BASE_URL` entry, so `APIConfiguration(key:)` always throws here, exercising
//  the `Failing*` fallback branch the factory exists to provide a safe degradation for — mirrors
//  `ReferenceDataSyncCoordinatorTests`'s "misconfigured Info.plist" factory test.
//

import XCTest
@testable import record_catch

@MainActor
final class CatchRecordServicesFactoryTests: XCTestCase {

    func test_make_whenBaseURLNotConfigured_returnsFailingServices() async {
        let services = CatchRecordServicesFactory.make(authenticator: { FakeAuthenticator() })

        await XCTAssertThrowsErrorAsync(try await services.catchRecords.retrieveCatchRecord(catchRecordId: "cr-1")) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
        await XCTAssertThrowsErrorAsync(try await services.vesselFavourites.listFavouriteGears(vesselId: "v1")) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
        await XCTAssertThrowsErrorAsync(try await services.platform.checkHealth()) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
    }

    func test_make_resolvesConsistently_forMultipleServiceCategories() async {
        // One `authenticator` closure backs all three connector categories (`catchRecords`,
        // `vesselFavourites`, `platform`) — proven here by every category independently degrading
        // to its own `Failing*` double rather than any category silently succeeding because it
        // was wired differently. `MSALAccessTokenProviderTests` separately proves the bridge
        // itself resolves the shared session's token correctly once a base URL is configured.
        let services = CatchRecordServicesFactory.make(authenticator: { FakeAuthenticator() })

        XCTAssertTrue(services.catchRecords is FailingCatchRecordService)
        XCTAssertTrue(services.vesselFavourites is FailingVesselFavouritesService)
        XCTAssertTrue(services.platform is FailingCatchRecordPlatformService)
    }

    func test_make_whenUITesting_returnsStubServices_regardlessOfConfiguration() async {
        // `isUITesting: true` short-circuits before `configuration` is even consulted — proven by
        // passing a `configuration` closure that would otherwise succeed, and still getting the
        // `Stub*` doubles (never live network access during XCUITest — ADR-0025).
        let services = CatchRecordServicesFactory.make(
            authenticator: { FakeAuthenticator() },
            isUITesting: true,
            configuration: { try APIConfiguration(bundle: Self.configuredBundle(), key: "CATCH_RECORD_API_BASE_URL") }
        )

        XCTAssertTrue(services.catchRecords is StubCatchRecordService)
        XCTAssertTrue(services.vesselFavourites is StubVesselFavouritesService)
        XCTAssertTrue(services.platform is StubCatchRecordPlatformService)
    }

    func test_make_whenBaseURLConfigured_returnsRealServices() async {
        let services = CatchRecordServicesFactory.make(
            authenticator: { FakeAuthenticator() },
            isUITesting: false,
            configuration: { try APIConfiguration(bundle: Self.configuredBundle(), key: "CATCH_RECORD_API_BASE_URL") }
        )

        XCTAssertTrue(services.catchRecords is CatchRecordService)
        XCTAssertTrue(services.vesselFavourites is VesselFavouritesService)
        XCTAssertTrue(services.platform is CatchRecordPlatformService)
    }

    private struct FakeInfoDictionary: InfoDictionaryProviding {
        let values: [String: Any]
        func object(forInfoDictionaryKey key: String) -> Any? { values[key] }
    }

    private static func configuredBundle() -> InfoDictionaryProviding {
        FakeInfoDictionary(values: ["MMOCRAppConfig": ["CATCH_RECORD_API_BASE_URL": "https://example.invalid"]])
    }
}
