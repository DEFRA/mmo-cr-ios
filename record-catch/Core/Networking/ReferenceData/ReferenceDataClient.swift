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
//  The live API has two distinct routes/response shapes for the dataset routes (verified by
//  direct probing of the running backend — see ADR-0018's correction note): a **collection**
//  route returning a `ReferenceDataEnvelope`, and a **single-item** route returning a **bare**
//  item object. `fetch<Item>` and `fetchItem<Item>` below model each shape separately rather than
//  forcing the bare item through the envelope decoder. `fetchManifest()` is a third, distinct
//  shape again — a single bare manifest object with no collection/item split (see ADR-0018
//  addendum "Manifest").
//

import Foundation

/// Fetches reference-data collections/items. Vessels, species, ports and the manifest are
/// exposed today; a future dataset adds new methods here following the same
/// `fetch<Item>`/`fetchItem<Item>` shape internally.
nonisolated protocol ReferenceDataFetching: Sendable {
    func fetchVessels() async throws -> [VesselOption]
    func fetchVessel(id: String) async throws -> VesselOption
    func fetchSpecies() async throws -> [SpeciesOption]
    func fetchSpecies(id: String) async throws -> SpeciesOption
    func fetchPorts() async throws -> [PortOption]
    func fetchPort(id: String) async throws -> PortOption
    func fetchManifest() async throws -> ReferenceDataManifest
}

/// Production implementation: builds a request via `makeReferenceDataRequest`/
/// `makeReferenceDataItemRequest`/`makeReferenceDataManifestRequest`, sends it via the injected
/// `HTTPPerforming`, and maps the HTTP status / decode result into `APIError` (see ADR-0018 §6
/// and its "Simplified error model" addendum). Logs method/path/status/duration and — on failure
/// — the API's own `errorCode`/`traceId` via `NetworkLogger` — never headers, the token, or the
/// response body.
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

    func fetchSpecies() async throws -> [SpeciesOption] {
        let envelope: ReferenceDataEnvelope<SpeciesDTO> = try await fetch(.species)
        return envelope.items.map(SpeciesOption.init(dto:))
    }

    func fetchSpecies(id: String) async throws -> SpeciesOption {
        let dto: SpeciesDTO = try await fetchItem(.species, itemId: id)
        return SpeciesOption(dto: dto)
    }

    func fetchPorts() async throws -> [PortOption] {
        let envelope: ReferenceDataEnvelope<PortDTO> = try await fetch(.ports)
        return envelope.items.map(PortOption.init(dto:))
    }

    func fetchPort(id: String) async throws -> PortOption {
        let dto: PortDTO = try await fetchItem(.ports, itemId: id)
        return PortOption(dto: dto)
    }

    func fetchManifest() async throws -> ReferenceDataManifest {
        let token = await resolvedToken()
        let request = makeReferenceDataManifestRequest(baseURL: configuration.baseURL, bearerToken: token)
        return try await send(request, fallbackPath: "manifest") { data in
            try self.decoder.decode(ReferenceDataManifest.self, from: data)
        }
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
        return try await send(request, fallbackPath: dataset.rawValue) { data in
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
        return try await send(request, fallbackPath: dataset.rawValue) { data in
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

    /// Sends `request`, logs it, maps any non-2xx status (or decoded error envelope) into
    /// `APIError.response`, and decodes the body with `decode` on success — shared by every
    /// route above. `fallbackPath` is used only if the request's URL is somehow absent, and is
    /// otherwise purely a logging label (e.g. `"manifest"`, or a `ReferenceDataset`'s raw value).
    private func send<Item>(
        _ request: URLRequest,
        fallbackPath: String,
        decode: (Data) throws -> Item
    ) async throws -> Item {
        let path = request.url?.path ?? fallbackPath
        let startedAt = Date()

        do {
            let (data, response) = try await httpClient.send(request)
            let duration = Date().timeIntervalSince(startedAt)
            let statusCode = response.statusCode
            let isSuccess = (200..<300).contains(statusCode)
            let details = isSuccess ? nil : Self.decodeErrorDetails(from: data, decoder: decoder)

            logger.log(NetworkLogEntry(
                method: "GET",
                path: path,
                statusCode: statusCode,
                durationSeconds: duration,
                errorCode: details?.code,
                traceId: details?.traceId
            ))

            guard isSuccess else {
                throw APIError.response(status: statusCode, details: details)
            }

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

    /// Best-effort decode of the API's standard error envelope (`{ "error": { ... } }`) from a
    /// non-2xx response body. Returns `nil` — never throws — when the body is empty or doesn't
    /// match the envelope shape, so a malformed error body can never mask the real HTTP-status
    /// failure (see ADR-0018 addendum "Simplified error model").
    private static func decodeErrorDetails(from data: Data, decoder: JSONDecoder) -> APIErrorDetails? {
        guard !data.isEmpty else { return nil }
        struct ErrorEnvelope: Decodable {
            let error: APIErrorDetails
        }
        return try? decoder.decode(ErrorEnvelope.self, from: data).error
    }

    private static func mapURLError(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .response(status: error.errorCode, details: nil)
        }
    }
}

/// Fixture-backed double for future call sites/tests, following the same "real + stub pair"
/// pattern as the existing `PortSearchProviding`/`FavouritePortsProviding` stubs (ADR-0004).
nonisolated struct StubReferenceDataClient: ReferenceDataFetching {
    var vessels: [VesselOption]
    var vessel: VesselOption?
    var species: [SpeciesOption]
    var speciesItem: SpeciesOption?
    var ports: [PortOption]
    var portItem: PortOption?
    var manifest: ReferenceDataManifest?
    var error: APIError?

    init(
        vessels: [VesselOption] = [],
        vessel: VesselOption? = nil,
        species: [SpeciesOption] = [],
        speciesItem: SpeciesOption? = nil,
        ports: [PortOption] = [],
        portItem: PortOption? = nil,
        manifest: ReferenceDataManifest? = nil,
        error: APIError? = nil
    ) {
        self.vessels = vessels
        self.vessel = vessel
        self.species = species
        self.speciesItem = speciesItem
        self.ports = ports
        self.portItem = portItem
        self.manifest = manifest
        self.error = error
    }

    func fetchVessels() async throws -> [VesselOption] {
        if let error { throw error }
        return vessels
    }

    func fetchVessel(id: String) async throws -> VesselOption {
        if let error { throw error }
        if let vessel { return vessel }
        throw APIError.response(status: 404, details: nil)
    }

    func fetchSpecies() async throws -> [SpeciesOption] {
        if let error { throw error }
        return species
    }

    func fetchSpecies(id: String) async throws -> SpeciesOption {
        if let error { throw error }
        if let speciesItem { return speciesItem }
        throw APIError.response(status: 404, details: nil)
    }

    func fetchPorts() async throws -> [PortOption] {
        if let error { throw error }
        return ports
    }

    func fetchPort(id: String) async throws -> PortOption {
        if let error { throw error }
        if let portItem { return portItem }
        throw APIError.response(status: 404, details: nil)
    }

    func fetchManifest() async throws -> ReferenceDataManifest {
        if let error { throw error }
        if let manifest { return manifest }
        throw APIError.response(status: 503, details: nil)
    }
}
