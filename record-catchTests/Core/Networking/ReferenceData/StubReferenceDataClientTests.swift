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

    // MARK: fetchSpecies

    func test_fetchSpecies_returnsConfiguredSpecies() async throws {
        let species = SpeciesOption(id: "1", name: "Atlantic cod (COD)")
        let sut = StubReferenceDataClient(species: [species])

        let result = try await sut.fetchSpecies()

        XCTAssertEqual(result, [species])
    }

    func test_fetchSpecies_throwsConfiguredError() async {
        let sut = StubReferenceDataClient(error: .unauthorized)

        do {
            _ = try await sut.fetchSpecies()
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_init_defaults_toEmptySpeciesAndNoError() async throws {
        let sut = StubReferenceDataClient()

        let result = try await sut.fetchSpecies()

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: fetchSpecies(id:)

    func test_fetchSpeciesItem_returnsConfiguredSpecies() async throws {
        let species = SpeciesOption(id: "1", name: "Atlantic cod (COD)")
        let sut = StubReferenceDataClient(speciesItem: species)

        let result = try await sut.fetchSpecies(id: "1")

        XCTAssertEqual(result, species)
    }

    func test_fetchSpeciesItem_throwsConfiguredError() async {
        let sut = StubReferenceDataClient(error: .unauthorized)

        do {
            _ = try await sut.fetchSpecies(id: "1")
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchSpeciesItem_throwsNotFound_whenNoSpeciesConfigured() async {
        let sut = StubReferenceDataClient()

        do {
            _ = try await sut.fetchSpecies(id: "unknown")
            XCTFail("Expected .notFound")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    // MARK: fetchPorts

    func test_fetchPorts_returnsConfiguredPorts() async throws {
        let port = PortOption(id: "1", name: "Aberdeen")
        let sut = StubReferenceDataClient(ports: [port])

        let result = try await sut.fetchPorts()

        XCTAssertEqual(result, [port])
    }

    func test_fetchPorts_throwsConfiguredError() async {
        let sut = StubReferenceDataClient(error: .unauthorized)

        do {
            _ = try await sut.fetchPorts()
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_init_defaults_toEmptyPortsAndNoError() async throws {
        let sut = StubReferenceDataClient()

        let result = try await sut.fetchPorts()

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: fetchPort(id:)

    func test_fetchPortItem_returnsConfiguredPort() async throws {
        let port = PortOption(id: "1", name: "Aberdeen")
        let sut = StubReferenceDataClient(portItem: port)

        let result = try await sut.fetchPort(id: "1")

        XCTAssertEqual(result, port)
    }

    func test_fetchPortItem_throwsConfiguredError() async {
        let sut = StubReferenceDataClient(error: .unauthorized)

        do {
            _ = try await sut.fetchPort(id: "1")
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func test_fetchPortItem_throwsNotFound_whenNoPortConfigured() async {
        let sut = StubReferenceDataClient()

        do {
            _ = try await sut.fetchPort(id: "unknown")
            XCTFail("Expected .notFound")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }
}
