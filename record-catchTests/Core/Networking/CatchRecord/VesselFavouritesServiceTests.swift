//
//  VesselFavouritesServiceTests.swift
//  record-catchTests
//
//  Covers `VesselFavouritesService` — one representative list/add/remove cycle per favourite kind,
//  plus idempotency-key validation and error mapping (shared machinery already covered in depth by
//  CatchRecordServiceTests, so not repeated exhaustively here).
//

import XCTest
@testable import record_catch

final class VesselFavouritesServiceTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private struct StaticTokenProvider: AuthTokenProviding {
        let token: String?
        func bearerToken() async throws -> String? { token }
    }

    private struct FakeInfoDictionary: InfoDictionaryProviding {
        let values: [String: Any]
        func object(forInfoDictionaryKey key: String) -> Any? { values[key] }
    }

    private func makeSUT(httpClient: HTTPPerforming) throws -> VesselFavouritesService {
        let configuration = try APIConfiguration(
            bundle: FakeInfoDictionary(values: ["MMOCRAppConfig": ["API_BASE_URL": baseURL.absoluteString]]),
            allowsInsecureHTTP: true
        )
        return VesselFavouritesService(httpClient: httpClient, configuration: configuration, tokenProvider: StaticTokenProvider(token: nil))
    }

    func test_listFavouriteGears_decodesResponse() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(#"{"vesselId":"v1","favouriteGearIds":["g1"]}"#.utf8))
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.listFavouriteGears(vesselId: "v1")

        XCTAssertEqual(response.favouriteGearIds, ["g1"])
    }

    func test_addFavouriteGear_sendsPOSTWithPayload() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(#"{"vesselId":"v1","favouriteGearIds":["g1"]}"#.utf8))
        let sut = try makeSUT(httpClient: httpClient)

        _ = try await sut.addFavouriteGear(vesselId: "v1", gearId: "g1", idempotencyKey: nil)

        XCTAssertEqual(httpClient.receivedRequests.first?.httpMethod, "POST")
        let body = try XCTUnwrap(httpClient.receivedRequests.first?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["gearId"] as? String, "g1")
    }

    func test_removeFavouriteGear_sendsDELETE_succeedsOn204() async throws {
        let httpClient = StubHTTPClient.statusOnly(204)
        let sut = try makeSUT(httpClient: httpClient)

        try await sut.removeFavouriteGear(vesselId: "v1", gearId: "g1")

        XCTAssertEqual(httpClient.receivedRequests.first?.httpMethod, "DELETE")
    }

    func test_listFavouriteSpecies_decodesResponse() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(#"{"vesselId":"v1","favouriteSpeciesIds":["s1"]}"#.utf8))
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.listFavouriteSpecies(vesselId: "v1")

        XCTAssertEqual(response.favouriteSpeciesIds, ["s1"])
    }

    func test_addFavouriteSpecies_throwsInvalidRequest_whenIdempotencyKeyEmpty() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(#"{"vesselId":"v1","favouriteSpeciesIds":[]}"#.utf8))
        let sut = try makeSUT(httpClient: httpClient)

        do {
            _ = try await sut.addFavouriteSpecies(vesselId: "v1", speciesId: "s1", idempotencyKey: "")
            XCTFail("Expected .invalidRequest")
        } catch let error as APIError {
            guard case .invalidRequest = error else { return XCTFail("Expected .invalidRequest, got \(error)") }
        }
        XCTAssertTrue(httpClient.receivedRequests.isEmpty)
    }

    func test_listFavouritePorts_decodesResponse() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: Data(#"{"vesselId":"v1","favouritePortIds":["p1"]}"#.utf8))
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.listFavouritePorts(vesselId: "v1")

        XCTAssertEqual(response.favouritePortIds, ["p1"])
    }

    func test_removeFavouritePort_mapsConflictStatus() async throws {
        let httpClient = StubHTTPClient.statusOnly(403)
        let sut = try makeSUT(httpClient: httpClient)

        do {
            try await sut.removeFavouritePort(vesselId: "v1", portId: "p1")
            XCTFail("Expected a 403 response")
        } catch let error as APIError {
            XCTAssertTrue(error.isForbidden)
        }
    }
}
