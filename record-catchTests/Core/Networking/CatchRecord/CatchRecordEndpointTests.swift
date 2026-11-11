//
//  CatchRecordEndpointTests.swift
//  record-catchTests
//
//  Pure request-building tests for the Catch Recording Service connector's 18 in-scope routes
//  (ADR-0025) — no network. Mirrors ReferenceDataEndpointTests.swift's style.
//

import XCTest
@testable import record_catch

final class CatchRecordEndpointTests: XCTestCase {

    private let baseURL = URL(string: "http://localhost:3002")!

    // MARK: Method + path, one representative per route family

    func test_health_isUnauthenticatedGET() {
        let request = makeCatchRecordRequest(route: .health, baseURL: baseURL, bearerToken: "secret")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/health")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func test_listExampleData_isUnauthenticatedGET() {
        let request = makeCatchRecordRequest(route: .listExampleData, baseURL: baseURL, bearerToken: "secret")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/example")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func test_listCatchRecords_buildsLimitAndStatusQueryItems() {
        let request = makeCatchRecordRequest(
            route: .listCatchRecords(limit: 10, status: .draft),
            baseURL: baseURL,
            bearerToken: nil
        )
        let components = URLComponents(url: try! XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "limit", value: "10")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "status", value: "DRAFT")))
    }

    func test_listCatchRecords_omitsQueryItems_whenNil() {
        let request = makeCatchRecordRequest(route: .listCatchRecords(limit: nil, status: nil), baseURL: baseURL, bearerToken: nil)
        XCTAssertNil(request.url?.query)
    }

    func test_createDraft_isPOST_toCatchRecordsCollection() throws {
        let request = try makeCatchRecordRequest(
            route: .createDraft,
            baseURL: baseURL,
            body: CreateDraftCatchRecordPayload(vesselId: "v1"),
            bearerToken: "token",
            idempotencyKey: "key-123",
            encoder: JSONEncoder()
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/catch-records")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "key-123")
    }

    func test_retrieveCatchRecord_isGET_withId() {
        let request = makeCatchRecordRequest(route: .retrieveCatchRecord(catchRecordId: "abc"), baseURL: baseURL, bearerToken: nil)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/catch-records/abc")
    }

    func test_replaceCatchRecord_isPUT_andSendsIfMatch() throws {
        let payload = CompleteReplacementPayload(
            vessel: VesselSnapshotDTO(id: "v", rssSnapshot: "A1", nameSnapshot: "N", externalMarkSnapshot: "E", lengthOverallMetresSnapshot: nil),
            trip: TripDTO(startedAndFinishedToday: true, dateStarted: "2026-11-11", dateEnded: "2026-11-11", departurePort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N"), returnPort: CatchRecordPortDTO(id: "p", codeSnapshot: "C", nameSnapshot: "N")),
            pairFishing: PairFishingDTO(enabled: false),
            gears: [],
            speciesNotLanded: []
        )
        let request = try makeCatchRecordRequest(
            route: .replaceCatchRecord(catchRecordId: "abc"),
            baseURL: baseURL,
            body: payload,
            bearerToken: nil,
            ifMatch: "3",
            encoder: JSONEncoder()
        )
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "If-Match"), "3")
    }

    func test_saveCatchRecordSection_isPATCH() throws {
        let request = try makeCatchRecordRequest(
            route: .saveCatchRecordSection(catchRecordId: "abc"),
            baseURL: baseURL,
            body: SectionPatchPayload.pairFishing(PairFishingDTO(enabled: false)),
            bearerToken: nil,
            ifMatch: "1",
            encoder: JSONEncoder()
        )
        XCTAssertEqual(request.httpMethod, "PATCH")
    }

    func test_abandonDraft_isDELETE_withIfMatchAndNoBody() {
        let request = makeCatchRecordRequest(route: .abandonDraft(catchRecordId: "abc"), baseURL: baseURL, bearerToken: nil, ifMatch: "2")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "If-Match"), "2")
        XCTAssertNil(request.httpBody)
    }

    func test_history_buildsPathAndLimitQueryItem() {
        let request = makeCatchRecordRequest(route: .history(catchRecordId: "abc", limit: 5), baseURL: baseURL, bearerToken: nil)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/catch-records/abc/history?limit=5")
    }

    func test_submit_isPOST_toSubmissionPath_withIfMatchAndIdempotencyKey() {
        let request = makeCatchRecordRequest(
            route: .submit(catchRecordId: "abc"),
            baseURL: baseURL,
            bearerToken: nil,
            ifMatch: "4",
            idempotencyKey: "idem-1"
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/catch-records/abc/submission")
        XCTAssertEqual(request.value(forHTTPHeaderField: "If-Match"), "4")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "idem-1")
    }

    func test_listSubmissions_isGET_toSubmissionsPath() {
        let request = makeCatchRecordRequest(route: .listSubmissions(catchRecordId: "abc"), baseURL: baseURL, bearerToken: nil)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/catch-records/abc/submissions")
    }

    func test_startEdit_isPOST_toEditStartPath() {
        let request = makeCatchRecordRequest(route: .startEdit(catchRecordId: "abc"), baseURL: baseURL, bearerToken: nil, ifMatch: "5")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/catch-records/abc/edit-start")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    // MARK: Vessel favourites

    func test_listFavouriteGears_buildsVesselPath() {
        let request = makeCatchRecordRequest(route: .listFavouriteGears(vesselId: "v1"), baseURL: baseURL, bearerToken: nil)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/vessels/v1/favourite-gears")
    }

    func test_removeFavouriteGear_appendsGearIdSegment() {
        let request = makeCatchRecordRequest(route: .removeFavouriteGear(vesselId: "v1", gearId: "g1"), baseURL: baseURL, bearerToken: nil)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/vessels/v1/favourite-gears/g1")
    }

    func test_addFavouriteSpecies_isPOST() throws {
        let request = try makeCatchRecordRequest(
            route: .addFavouriteSpecies(vesselId: "v1"),
            baseURL: baseURL,
            body: FavouriteSpeciesPayload(speciesId: "s1"),
            bearerToken: nil,
            encoder: JSONEncoder()
        )
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/vessels/v1/favourite-species")
    }

    func test_removeFavouritePort_appendsPortIdSegment() {
        let request = makeCatchRecordRequest(route: .removeFavouritePort(vesselId: "v1", portId: "p1"), baseURL: baseURL, bearerToken: nil)
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3002/v1/vessels/v1/favourite-ports/p1")
    }

    // MARK: Headers shared by every route

    func test_everyRoute_setsAcceptAndContentTypeHeaders() {
        let request = makeCatchRecordRequest(route: .health, baseURL: baseURL, bearerToken: nil)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_correlationHeader_defaultsToNonEmpty_andDiffersAcrossCalls() {
        let first = makeCatchRecordRequest(route: .health, baseURL: baseURL, bearerToken: nil)
        let second = makeCatchRecordRequest(route: .health, baseURL: baseURL, bearerToken: nil)
        XCTAssertFalse(first.value(forHTTPHeaderField: "x-cdp-request-id")?.isEmpty ?? true)
        XCTAssertNotEqual(
            first.value(forHTTPHeaderField: "x-cdp-request-id"),
            second.value(forHTTPHeaderField: "x-cdp-request-id")
        )
    }

    func test_correlationHeader_usesProvidedFixedValue() {
        let request = makeCatchRecordRequest(route: .health, baseURL: baseURL, bearerToken: nil, requestId: "fixed-id")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-cdp-request-id"), "fixed-id")
    }

    // MARK: Path-prefixed base URL (CDP gateway)

    func test_preservesBasePathPrefix() {
        let prefixedBaseURL = URL(string: "https://mmo-cr-catch-recording-service.api.dev.cdp-int.defra.cloud/catch-record-service")!
        let request = makeCatchRecordRequest(route: .retrieveCatchRecord(catchRecordId: "abc"), baseURL: prefixedBaseURL, bearerToken: nil)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://mmo-cr-catch-recording-service.api.dev.cdp-int.defra.cloud/catch-record-service/v1/catch-records/abc"
        )
    }
}
