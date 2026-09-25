//
//  StubReferenceDataClientTests.swift
//  record-catchTests
//
//  Covers `StubReferenceDataClient`, the fixture-backed double provided alongside
//  `RemoteReferenceDataClient` for future call sites/tests (see ADR-0018 §1). Not otherwise
//  exercised by any other test in this suite, since it isn't wired into a view model yet.
//

import XCTest
@testable import record_catch

final class StubReferenceDataClientTests: XCTestCase {

    // MARK: fetchVessels

    func test_fetchVessels_returnsConfiguredVessels() async throws {
        let vessel = VesselOption(id: "1", name: "ACHILLES")
        let sut = StubReferenceDataClient(vessels: [vessel])

        let result = try await sut.fetchVessels()

        XCTAssertEqual(result, [vessel])
    }

    func test_fetchVessels_throwsConfiguredError() async {
        let sut = StubReferenceDataClient(error: .unauthorized)

        do {
            _ = try await sut.fetchVessels()
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_init_defaults_toEmptyVesselsAndNoError() async throws {
        let sut = StubReferenceDataClient()

        let result = try await sut.fetchVessels()

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: fetchVessel

    func test_fetchVessel_returnsConfiguredVessel() async throws {
        let vessel = VesselOption(id: "1", name: "ACHILLES")
        let sut = StubReferenceDataClient(vessel: vessel)

        let result = try await sut.fetchVessel(id: "1")

        XCTAssertEqual(result, vessel)
    }

    func test_fetchVessel_throwsConfiguredError() async {
        let sut = StubReferenceDataClient(error: .unauthorized)

        do {
            _ = try await sut.fetchVessel(id: "1")
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchVessel_throwsNotFound_whenNoVesselConfigured() async {
        let sut = StubReferenceDataClient()

        do {
            _ = try await sut.fetchVessel(id: "unknown")
            XCTFail("Expected .notFound")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }
}
