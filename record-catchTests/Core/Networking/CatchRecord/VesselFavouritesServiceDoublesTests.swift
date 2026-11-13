//
//  VesselFavouritesServiceDoublesTests.swift
//  record-catchTests
//
//  Covers `StubVesselFavouritesService` and `FailingVesselFavouritesService` — the fixture-backed
//  and always-fails doubles declared alongside the production `VesselFavouritesService`
//  (ADR-0025). See `CatchRecordServiceDoublesTests.swift`'s doc comment for why these are tested
//  even though neither double is wired to a screen yet.
//

import XCTest
@testable import record_catch

final class VesselFavouritesServiceDoublesTests: XCTestCase {

    // MARK: - StubVesselFavouritesService

    func test_stub_listFavouriteGears_returnsConfiguredResponse() async throws {
        let response = FavouriteGearsResponseDTO(vesselId: "v1", favouriteGearIds: ["g1"])
        let sut = StubVesselFavouritesService(gearsResponse: response)

        let result = try await sut.listFavouriteGears(vesselId: "v1")

        XCTAssertEqual(result, response)
    }

    func test_stub_listFavouriteGears_fallsBackToEmptyList_whenNoResponseConfigured() async throws {
        let sut = StubVesselFavouritesService()

        let result = try await sut.listFavouriteGears(vesselId: "v1")

        XCTAssertEqual(result, FavouriteGearsResponseDTO(vesselId: "v1", favouriteGearIds: []))
    }

    func test_stub_addFavouriteGear_fallsBackToEchoingTheAddedGear() async throws {
        let sut = StubVesselFavouritesService()

        let result = try await sut.addFavouriteGear(vesselId: "v1", gearId: "g1", idempotencyKey: "idem-1")

        XCTAssertEqual(result, FavouriteGearsResponseDTO(vesselId: "v1", favouriteGearIds: ["g1"]))
    }

    func test_stub_removeFavouriteGear_succeeds_whenNoErrorConfigured() async throws {
        let sut = StubVesselFavouritesService()
        try await sut.removeFavouriteGear(vesselId: "v1", gearId: "g1")
    }

    func test_stub_removeFavouriteGear_throwsConfiguredError() async {
        let sut = StubVesselFavouritesService(error: .invalidConfiguration)
        await XCTAssertThrowsErrorAsync(try await sut.removeFavouriteGear(vesselId: "v1", gearId: "g1")) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
    }

    func test_stub_listFavouriteSpecies_fallsBackToEmptyList_whenNoResponseConfigured() async throws {
        let sut = StubVesselFavouritesService()

        let result = try await sut.listFavouriteSpecies(vesselId: "v1")

        XCTAssertEqual(result, FavouriteSpeciesResponseDTO(vesselId: "v1", favouriteSpeciesIds: []))
    }

    func test_stub_addFavouriteSpecies_fallsBackToEchoingTheAddedSpecies() async throws {
        let sut = StubVesselFavouritesService()

        let result = try await sut.addFavouriteSpecies(vesselId: "v1", speciesId: "s1", idempotencyKey: nil)

        XCTAssertEqual(result, FavouriteSpeciesResponseDTO(vesselId: "v1", favouriteSpeciesIds: ["s1"]))
    }

    func test_stub_removeFavouriteSpecies_throwsConfiguredError() async {
        let sut = StubVesselFavouritesService(error: .invalidConfiguration)
        await XCTAssertThrowsErrorAsync(try await sut.removeFavouriteSpecies(vesselId: "v1", speciesId: "s1")) {
            XCTAssertEqual($0 as? APIError, .invalidConfiguration)
        }
    }

    func test_stub_listFavouritePorts_returnsConfiguredResponse() async throws {
        let response = FavouritePortsResponseDTO(vesselId: "v1", favouritePortIds: ["p1"])
        let sut = StubVesselFavouritesService(portsResponse: response)

        let result = try await sut.listFavouritePorts(vesselId: "v1")

        XCTAssertEqual(result, response)
    }

    func test_stub_addFavouritePort_fallsBackToEchoingTheAddedPort() async throws {
        let sut = StubVesselFavouritesService()

        let result = try await sut.addFavouritePort(vesselId: "v1", portId: "p1", idempotencyKey: "idem-1")

        XCTAssertEqual(result, FavouritePortsResponseDTO(vesselId: "v1", favouritePortIds: ["p1"]))
    }

    func test_stub_removeFavouritePort_succeeds_whenNoErrorConfigured() async throws {
        let sut = StubVesselFavouritesService()
        try await sut.removeFavouritePort(vesselId: "v1", portId: "p1")
    }

    // MARK: - FailingVesselFavouritesService — every method throws .invalidConfiguration

    func test_failing_everyMethod_throwsInvalidConfiguration() async {
        let sut = FailingVesselFavouritesService()

        await XCTAssertThrowsErrorAsync(try await sut.listFavouriteGears(vesselId: "v1")) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.addFavouriteGear(vesselId: "v1", gearId: "g1", idempotencyKey: nil)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.removeFavouriteGear(vesselId: "v1", gearId: "g1")) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.listFavouriteSpecies(vesselId: "v1")) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.addFavouriteSpecies(vesselId: "v1", speciesId: "s1", idempotencyKey: nil)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.removeFavouriteSpecies(vesselId: "v1", speciesId: "s1")) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.listFavouritePorts(vesselId: "v1")) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.addFavouritePort(vesselId: "v1", portId: "p1", idempotencyKey: nil)) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
        await XCTAssertThrowsErrorAsync(try await sut.removeFavouritePort(vesselId: "v1", portId: "p1")) { XCTAssertEqual($0 as? APIError, .invalidConfiguration) }
    }
}
