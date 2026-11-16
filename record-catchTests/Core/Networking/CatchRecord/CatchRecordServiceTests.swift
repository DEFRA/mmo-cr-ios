//
//  CatchRecordServiceTests.swift
//  record-catchTests
//
//  Covers `CatchRecordService`: happy-path decoding for a representative route from each HTTP
//  method family, client-side precondition rejection (never sends a request), HTTP-status error
//  mapping (including the Catch Recording Service's flat error envelope), and the
//  never-log-the-token security property. Mirrors CatchRecordServiceTests' predecessor and
//  ReferenceDataClientTests.swift's structure.
//

import XCTest
@testable import record_catch

final class CatchRecordServiceTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    private struct StaticTokenProvider: AuthTokenProviding {
        let token: String?
        func bearerToken() async throws -> String? { token }
    }

    private func makeConfiguration() throws -> APIConfiguration {
        try APIConfiguration(
            bundle: FakeInfoDictionary(values: ["MMOCRAppConfig": ["API_BASE_URL": baseURL.absoluteString]]),
            allowsInsecureHTTP: true
        )
    }

    private struct FakeInfoDictionary: InfoDictionaryProviding {
        let values: [String: Any]
        func object(forInfoDictionaryKey key: String) -> Any? { values[key] }
    }

    private func makeSUT(httpClient: HTTPPerforming, token: String? = nil, logger: NetworkLogger = NetworkLogger()) throws -> CatchRecordService {
        CatchRecordService(
            httpClient: httpClient,
            configuration: try makeConfiguration(),
            tokenProvider: StaticTokenProvider(token: token),
            logger: logger
        )
    }

    private let saveResponseJSON = Data("""
    {
      "id": "cr-1", "catchRecordReference": "A12345-11112026-100000", "status": "DRAFT",
      "displayStatus": "Draft", "version": 1, "savedSection": null,
      "sectionCompletion": { "trip": false, "pairFishing": false, "gears": false },
      "progress": {
        "hasUnsubmittedChanges": false, "numberOfSubmissions": 0,
        "incompleteGearAssociationIds": [], "currentIncompleteGearAssociationId": null,
        "allGearsComplete": false
      }
    }
    """.utf8)

    // MARK: Happy path — one representative route per HTTP method

    func test_createDraft_POST_decodesStandardSaveResponse() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 201, jsonData: saveResponseJSON)
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.createDraft(vesselId: "v1", catchRecordReference: "A12345-11112026-100000", idempotencyKey: nil)

        XCTAssertEqual(response.id, "cr-1")
        XCTAssertEqual(httpClient.receivedRequests.first?.httpMethod, "POST")
    }

    func test_listCatchRecords_GET_decodesListResponse() async throws {
        let json = Data(#"{"items":[],"limit":20,"count":0}"#.utf8)
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: json)
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.listCatchRecords(limit: 20, status: nil)

        XCTAssertEqual(response.count, 0)
    }

    func test_replaceCatchRecord_PUT_sendsIfMatchAndDecodesResponse() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: saveResponseJSON)
        let sut = try makeSUT(httpClient: httpClient)
        let payload = CompleteReplacementPayload(
            vessel: VesselSnapshotDTO(id: "v", rssSnapshot: "A1", nameSnapshot: "N", externalMarkSnapshot: "E", lengthOverallMetresSnapshot: nil),
            trip: TripDTO(startedAndFinishedToday: true, dateStarted: "2026-11-11", dateEnded: "2026-11-11", departurePort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N"), returnPort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N")),
            pairFishing: PairFishingDTO(enabled: false),
            gears: [],
            speciesNotLanded: []
        )

        _ = try await sut.replaceCatchRecord(catchRecordId: "cr-1", expectedVersion: 3, payload: payload)

        XCTAssertEqual(httpClient.receivedRequests.first?.httpMethod, "PUT")
        XCTAssertEqual(httpClient.receivedRequests.first?.value(forHTTPHeaderField: "If-Match"), "3")
    }

    func test_saveSection_PATCH_sendsIfMatch() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: saveResponseJSON)
        let sut = try makeSUT(httpClient: httpClient)

        _ = try await sut.saveSection(catchRecordId: "cr-1", expectedVersion: 2, section: .pairFishing(PairFishingDTO(enabled: false)))

        XCTAssertEqual(httpClient.receivedRequests.first?.httpMethod, "PATCH")
        XCTAssertEqual(httpClient.receivedRequests.first?.value(forHTTPHeaderField: "If-Match"), "2")
    }

    func test_abandonDraft_DELETE_succeeds_on204() async throws {
        let httpClient = StubHTTPClient.statusOnly(204)
        let sut = try makeSUT(httpClient: httpClient)

        try await sut.abandonDraft(catchRecordId: "cr-1", expectedVersion: 1)

        XCTAssertEqual(httpClient.receivedRequests.first?.httpMethod, "DELETE")
    }

    func test_history_decodesEvents() async throws {
        let json = Data("""
        {"catchRecordId":"cr-1","status":"DRAFT","displayStatus":"Draft","version":1,
         "hasUnsubmittedChanges":true,"numberOfSubmissions":0,
         "events":[{"id":"e1","eventType":"DRAFT_CREATED","timestamp":"2026-11-11T09:00:00Z","actor":"user-1"}]}
        """.utf8)
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: json)
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.history(catchRecordId: "cr-1", limit: nil)

        XCTAssertEqual(response.events.count, 1)
    }

    func test_submit_decodesSubmissionResponse() async throws {
        let json = Data("""
        {
          "id": "cr-1", "catchRecordReference": "A12345-11112026-100000", "status": "SUBMITTED",
          "displayStatus": "Submitted", "version": 2, "savedSection": null,
          "sectionCompletion": { "trip": true, "pairFishing": true, "gears": true },
          "progress": {
            "hasUnsubmittedChanges": false, "numberOfSubmissions": 1,
            "incompleteGearAssociationIds": [], "currentIncompleteGearAssociationId": null,
            "allGearsComplete": true
          },
          "submittedAt": "2026-11-11T10:00:00Z", "submittedBy": "user-1",
          "artifacts": [{ "submissionNumber": 1, "type": "JSON_SNAPSHOT" }]
        }
        """.utf8)
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: json)
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.submit(catchRecordId: "cr-1", expectedVersion: 1, idempotencyKey: "idem-1")

        XCTAssertEqual(response.submittedBy, "user-1")
        XCTAssertEqual(httpClient.receivedRequests.first?.value(forHTTPHeaderField: "Idempotency-Key"), "idem-1")
    }

    func test_listSubmissions_decodesSubmissionGroups() async throws {
        let json = Data("""
        {"catchRecordId":"cr-1","count":1,"submissions":[
          {"submissionNumber":1,"artifacts":[
            {"type":"pdf","contentType":"application/pdf","contentLength":1024,"checksum":"abc"}
          ]}
        ]}
        """.utf8)
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: json)
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.listSubmissions(catchRecordId: "cr-1")

        XCTAssertEqual(response.submissions.first?.artifacts.first?.type, .pdf)
    }

    func test_startEdit_decodesStandardSaveResponse() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: saveResponseJSON)
        let sut = try makeSUT(httpClient: httpClient)

        let response = try await sut.startEdit(catchRecordId: "cr-1", expectedVersion: 4, idempotencyKey: nil)

        XCTAssertEqual(response.status, .draft)
    }

    // MARK: Client-side precondition rejection — nothing is ever sent

    func test_replaceCatchRecord_throwsInvalidRequest_andSendsNothing_whenVersionIsZero() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: saveResponseJSON)
        let sut = try makeSUT(httpClient: httpClient)
        let payload = CompleteReplacementPayload(
            vessel: VesselSnapshotDTO(id: "v", rssSnapshot: "A1", nameSnapshot: "N", externalMarkSnapshot: "E", lengthOverallMetresSnapshot: nil),
            trip: TripDTO(startedAndFinishedToday: true, dateStarted: "2026-11-11", dateEnded: "2026-11-11", departurePort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N"), returnPort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N")),
            pairFishing: PairFishingDTO(enabled: false),
            gears: [],
            speciesNotLanded: []
        )

        do {
            _ = try await sut.replaceCatchRecord(catchRecordId: "cr-1", expectedVersion: 0, payload: payload)
            XCTFail("Expected .invalidRequest")
        } catch let error as APIError {
            guard case .invalidRequest = error else { return XCTFail("Expected .invalidRequest, got \(error)") }
        }
        XCTAssertTrue(httpClient.receivedRequests.isEmpty)
    }

    func test_listCatchRecords_throwsInvalidRequest_andSendsNothing_whenLimitOutOfRange() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: saveResponseJSON)
        let sut = try makeSUT(httpClient: httpClient)

        do {
            _ = try await sut.listCatchRecords(limit: 0, status: nil)
            XCTFail("Expected .invalidRequest")
        } catch let error as APIError {
            guard case .invalidRequest = error else { return XCTFail("Expected .invalidRequest, got \(error)") }
        }
        XCTAssertTrue(httpClient.receivedRequests.isEmpty)
    }

    func test_submit_throwsInvalidRequest_andSendsNothing_whenIdempotencyKeyTooLong() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: saveResponseJSON)
        let sut = try makeSUT(httpClient: httpClient)

        do {
            _ = try await sut.submit(catchRecordId: "cr-1", expectedVersion: 1, idempotencyKey: String(repeating: "a", count: 257))
            XCTFail("Expected .invalidRequest")
        } catch let error as APIError {
            guard case .invalidRequest = error else { return XCTFail("Expected .invalidRequest, got \(error)") }
        }
        XCTAssertTrue(httpClient.receivedRequests.isEmpty)
    }

    // MARK: Error mapping — the Catch Recording Service's flat error envelope

    func test_errorEnvelope_mapsCorrelationIdToTraceId_andDropsMessage() async throws {
        let httpClient = StubHTTPClient.success(statusCode: 409, jsonData: Data("""
        {"statusCode":409,"code":"DUPLICATE_RESOURCE","message":"A record with this reference already exists.","correlationId":"4c2c4e3a-0000-4000-8000-000000000000"}
        """.utf8))
        let sut = try makeSUT(httpClient: httpClient)

        do {
            _ = try await sut.createDraft(vesselId: "v1", catchRecordReference: nil, idempotencyKey: nil)
            XCTFail("Expected an error")
        } catch let error as APIError {
            XCTAssertTrue(error.isConflict)
            XCTAssertEqual(error.errorCode, "DUPLICATE_RESOURCE")
            XCTAssertEqual(error.traceId, "4c2c4e3a-0000-4000-8000-000000000000")
        }
    }

    func test_statusCodes_mapToExpectedAPIErrorHelpers() async throws {
        let cases: [(Int, (APIError) -> Bool)] = [
            (401, \.isUnauthorized),
            (403, \.isForbidden),
            (404, \.isNotFound),
            (409, \.isConflict),
            (413, \.isPayloadTooLarge),
            (422, \.isUnprocessable),
            (503, \.isServiceUnavailable)
        ]
        for (statusCode, predicate) in cases {
            let httpClient = StubHTTPClient.statusOnly(statusCode)
            let sut = try makeSUT(httpClient: httpClient)
            do {
                _ = try await sut.retrieveCatchRecord(catchRecordId: "cr-1")
                XCTFail("Expected a \(statusCode) response")
            } catch let error as APIError {
                XCTAssertTrue(predicate(error), "Status \(statusCode) did not map to the expected helper")
            }
        }
    }

    func test_offlineAndTimeout_mapToExpectedAPIError() async throws {
        let offlineClient = StubHTTPClient.failure(URLError(.notConnectedToInternet))
        let offlineSUT = try makeSUT(httpClient: offlineClient)
        do {
            _ = try await offlineSUT.retrieveCatchRecord(catchRecordId: "cr-1")
            XCTFail("Expected .offline")
        } catch let error as APIError {
            XCTAssertEqual(error, .offline)
        }

        let timeoutClient = StubHTTPClient.failure(URLError(.timedOut))
        let timeoutSUT = try makeSUT(httpClient: timeoutClient)
        do {
            _ = try await timeoutSUT.retrieveCatchRecord(catchRecordId: "cr-1")
            XCTFail("Expected .timedOut")
        } catch let error as APIError {
            XCTAssertEqual(error, .timedOut)
        }
    }

    // MARK: Security — never logs the token or headers

    func test_neverLogsTokenOrAuthorizationHeader() async throws {
        let sink = RecordingNetworkLogSink()
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: saveResponseJSON)
        let sut = try makeSUT(httpClient: httpClient, token: "super-secret-token", logger: NetworkLogger(sink: sink))

        _ = try await sut.startEdit(catchRecordId: "cr-1", expectedVersion: 1, idempotencyKey: nil)

        XCTAssertFalse(sink.messages.isEmpty)
        for message in sink.messages {
            XCTAssertFalse(message.contains("super-secret-token"))
            XCTAssertFalse(message.contains("Authorization"))
        }
    }

    func test_proceedsWithoutToken_whenTokenProviderThrows() async throws {
        struct ThrowingTokenProvider: AuthTokenProviding {
            struct Failure: Error {}
            func bearerToken() async throws -> String? { throw Failure() }
        }
        let httpClient = StubHTTPClient.success(statusCode: 200, jsonData: saveResponseJSON)
        let sut = CatchRecordService(httpClient: httpClient, configuration: try makeConfiguration(), tokenProvider: ThrowingTokenProvider())

        _ = try await sut.startEdit(catchRecordId: "cr-1", expectedVersion: 1, idempotencyKey: nil)

        XCTAssertNil(httpClient.receivedRequests.first?.value(forHTTPHeaderField: "Authorization"))
    }
}
