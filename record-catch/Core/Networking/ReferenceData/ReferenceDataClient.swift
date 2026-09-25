//
//  ReferenceDataClient.swift
//  record-catch
//
//  The reference-data API connector (see ADR-0018). `RemoteReferenceDataClient` is the production
//  implementation, composed from `HTTPPerforming` + `APIConfiguration` + `AuthTokenProviding` so it
//  is unit-testable with an in-memory `StubHTTPClient` and requires no live network in the test
//  suite (testing.instructions.md). `StubReferenceDataClient` is a fixture-backed double for
//  future call sites/tests. **Neither is wired into `AppEnvironment` or any view model in this
//  change** — this is the connector only (see ADR-0018 for the exact scope boundary).
//
//  The live API has two distinct routes/response shapes for the `vessels` dataset (verified by
//  direct probing of the running backend — see ADR-0018's correction note): a **collection** route
//  returning a `ReferenceDataEnvelope`, and a **single-item** route returning a **bare** item
//  object. `fetch<Item>` and `fetchItem<Item>` below model each shape separately rather than
//  forcing the bare item through the envelope decoder.
//

import Foundation

/// Fetches reference-data collections/items. Only vessels are exposed today; a future dataset adds
/// new methods here following the same `fetch<Item>`/`fetchItem<Item>` shape internally.
nonisolated protocol ReferenceDataFetching: Sendable {
    func fetchVessels() async throws -> [VesselOption]
    func fetchVessel(id: String) async throws -> VesselOption
}

/// Production implementation: builds a request via `makeReferenceDataRequest`/
/// `makeReferenceDataItemRequest`, sends it via the injected `HTTPPerforming`, and maps the HTTP
/// status / decode result into `APIError` (see the mapping table in ADR-0018 §6). Logs
/// method/path/status/duration via `NetworkLogger` — never headers, the token, or the response
/// body.
nonisolated struct RemoteReferenceDataClient: ReferenceDataFetching {
    private let httpClient: HTTPPerforming
    private let configuration: APIConfiguration
    private let tokenProvider: AuthTokenProviding
    private let logger: NetworkLogger
    private let decoder: JSONDecoder

    init(
        httpClient: HTTPPerforming,
        configuration: APIConfiguration,
        tokenProvider: AuthTokenProviding,
        logger: NetworkLogger = NetworkLogger()
    ) {
        self.httpClient = httpClient
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.logger = logger
        self.decoder = JSONDecoder()
    }

    func fetchVessels() async throws -> [VesselOption] {
        let envelope: ReferenceDataEnvelope<VesselDTO> = try await fetch(.vessels)
        return envelope.items.map(VesselOption.init(dto:))
    }

    func fetchVessel(id: String) async throws -> VesselOption {
        let dto: VesselDTO = try await fetchItem(.vessels, itemId: id)
        return VesselOption(dto: dto)
    }

    /// Fetches and decodes an envelope for `dataset`'s collection route, mapping every failure
    /// mode into `APIError`. Generic over `Item` so a future dataset reuses this exact path.
    private func fetch<Item: Decodable & Sendable>(
        _ dataset: ReferenceDataset
    ) async throws -> ReferenceDataEnvelope<Item> {
        let token = await resolvedToken()
        let request = makeReferenceDataRequest(
            baseURL: configuration.baseURL,
            dataset: dataset,
            bearerToken: token
        )
        return try await send(request, dataset: dataset) { data in
            try self.decoder.decode(ReferenceDataEnvelope<Item>.self, from: data)
        }
    }

    /// Fetches and decodes a **bare** item for `dataset`/`itemId`'s single-item route, mapping
    /// every failure mode into `APIError`. Generic over `Item` so a future dataset reuses this
    /// exact path. Deliberately does **not** reuse the envelope decoder above — the single-item
    /// response is not wrapped.
    private func fetchItem<Item: Decodable & Sendable>(
        _ dataset: ReferenceDataset,
        itemId: String
    ) async throws -> Item {
        let token = await resolvedToken()
        let request = makeReferenceDataItemRequest(
            baseURL: configuration.baseURL,
            dataset: dataset,
            itemId: itemId,
            bearerToken: token
        )
        return try await send(request, dataset: dataset) { data in
            try self.decoder.decode(Item.self, from: data)
        }
    }

    /// Resolves the bearer token, proceeding with `nil` (i.e. no `Authorization` header) if the
    /// provider throws — see the doc comment on `ThrowingTokenProvider` in the test suite for why.
    private func resolvedToken() async -> String? {
        do {
            return try await tokenProvider.bearerToken()
        } catch {
            return nil
        }
    }

    /// Sends `request`, logs it, maps the HTTP status into `APIError`, and decodes the body with
    /// `decode` on success — shared by both the collection and single-item routes above.
    private func send<Item>(
        _ request: URLRequest,
        dataset: ReferenceDataset,
        decode: (Data) throws -> Item
    ) async throws -> Item {
        let path = request.url?.path ?? dataset.rawValue
        let startedAt = Date()

        do {
            let (data, response) = try await httpClient.send(request)
            let duration = Date().timeIntervalSince(startedAt)
            logger.log(NetworkLogEntry(
                method: "GET",
                path: path,
                statusCode: response.statusCode,
                durationSeconds: duration
            ))

            try Self.throwIfError(for: response.statusCode)

            do {
                return try decode(data)
            } catch let decodingError as DecodingError {
                throw APIError.decoding(String(describing: decodingError))
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            let duration = Date().timeIntervalSince(startedAt)
            logger.log(NetworkLogEntry(method: "GET", path: path, statusCode: nil, durationSeconds: duration))
            throw Self.mapURLError(error)
        }
    }

    /// Maps an HTTP status code to `APIError`, or does nothing for `2xx`.
    private static func throwIfError(for statusCode: Int) throws {
        switch statusCode {
        case 200..<300:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 400..<500:
            throw APIError.transport(code: statusCode)
        case 500..<600:
            throw APIError.server(status: statusCode)
        default:
            throw APIError.transport(code: statusCode)
        }
    }

    private static func mapURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .transport(code: error.errorCode)
        }
    }
}

/// Fixture-backed double for future call sites/tests, following the same "real + stub pair"
/// pattern as the existing `PortSearchProviding`/`FavouritePortsProviding` stubs (ADR-0004).
nonisolated struct StubReferenceDataClient: ReferenceDataFetching {
    var vessels: [VesselOption]
    var vessel: VesselOption?
    var error: APIError?

    init(vessels: [VesselOption] = [], vessel: VesselOption? = nil, error: APIError? = nil) {
        self.vessels = vessels
        self.vessel = vessel
        self.error = error
    }

    func fetchVessels() async throws -> [VesselOption] {
        if let error { throw error }
        return vessels
    }

    func fetchVessel(id: String) async throws -> VesselOption {
        if let error { throw error }
        if let vessel { return vessel }
        throw APIError.notFound
    }
}
