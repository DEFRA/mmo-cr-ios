//
//  ReferenceDataClient.swift
//  record-catch
//
//  The reference-data API connector (see ADR-0018). `RemoteReferenceDataClient` is the production
//  implementation, composed from `HTTPPerforming` + `APIConfiguration` + `AuthTokenProviding` so it
//  is unit-testable with an in-memory `StubHTTPClient` and requires no live network in the test
//  suite (testing.instructions.md). `StubReferenceDataClient` is a fixture-backed double for
//  future call sites/tests. Wired into the app via `ReferenceDataSyncCoordinator.make(store:
//  connectivityMonitor:)` (see ADR-0024) — `RecordCatchApp` constructs one `RemoteReferenceDataClient`
//  per launch and hands it to `ReferenceDataSyncService`; no view model talks to this protocol
//  directly.
//
//  The live API has two distinct routes/response shapes for the dataset routes (verified by
//  direct probing of the running backend — see ADR-0018's correction note): a **collection**
//  route returning a `ReferenceDataEnvelope`, and a **single-item** route returning a **bare**
//  item object. `fetch<Item>` and `fetchItem<Item>` below model each shape separately rather than
//  forcing the bare item through the envelope decoder. `fetchManifest()` is a third, distinct
//  shape again — a single bare manifest object with no collection/item split (see ADR-0018
//  addendum "Manifest"). `checkHealth()` is a fourth shape: it discards the response body
//  entirely and only cares about the HTTP status, since `/health`'s body is undocumented (see
//  `makeReferenceDataHealthRequest`'s doc comment in `ReferenceDataEndpoint.swift`).
//

import Foundation

/// Fetches reference-data collections/items. Vessels, species, ports, the manifest and the
/// service's `/health` liveness probe are exposed today; a future dataset adds new methods here
/// following the same `fetch<Item>`/`fetchItem<Item>` shape internally.
nonisolated protocol ReferenceDataFetching: Sendable {
    func fetchVessels() async throws -> [VesselOption]
    func fetchVessel(id: String) async throws -> VesselOption
    func fetchSpecies() async throws -> [SpeciesOption]
    func fetchSpecies(id: String) async throws -> SpeciesOption
    func fetchPorts() async throws -> [PortOption]
    func fetchPort(id: String) async throws -> PortOption
    /// Fetches `GET {baseURL}/api/v1/reference-data/gears?view=mobile` and maps every item into a
    /// `GearOption` (see ADR-0018 addendum "gears dataset"). Unlike every other dataset here, this
    /// sends `?view=mobile` rather than the canonical view — see `ReferenceDataEndpoint.swift`'s
    /// file-level doc comment for why. There is deliberately no `fetchGear(id:)`: the live API's
    /// single-item route returns a bare item with no `measurements` catalogue, so it carries no
    /// labels to resolve a gear's measurement ids against.
    func fetchGears() async throws -> [GearOption]
    func fetchManifest() async throws -> ReferenceDataManifest
    /// Fetches the raw bytes at `urlString` — a blob dataset's (`map-land`/`map-statistical-areas`
    /// — see ADR—0024 "Map data") per-dataset download location, taken verbatim from that
    /// dataset's `ReferenceDataManifestEntry.url`. Unlike every other dataset in this protocol,
    /// blob datasets have no fixed `/reference-data/{dataset}` route to request instead — the
    /// manifest's `url` is the *only* way to know where to fetch one from. An absolute `urlString`
    /// is used as-is; a scheme-less value is resolved against the configured API base URL.
    func fetchBlob(urlString: String) async throws -> Data
    /// Pings `GET {baseURL}/health`. Succeeds (returns) on any 2xx response and throws `APIError`
    /// otherwise — see `makeReferenceDataHealthRequest`'s doc comment for why no response body is
    /// decoded or modelled.
    func checkHealth() async throws
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

    /// Fetches `gears` by requesting **both** the canonical (default) view and the `?view=mobile`
    /// view concurrently and joining them (see ADR-0024 "Gears from two requests" — a temporary
    /// backend-data limitation, not the connector's preferred design): only the canonical view's
    /// `applicableCharacteristics.fixed` says which measurements are required vs per-trip, and
    /// only the mobile view's `measurements` catalogue gives those measurements a label/unit.
    ///
    /// - Throws: `ReferenceDataValidationError.gearViewsMismatch` if the two responses disagree on
    ///   `version`/`collectionId`/the set of gear codes present (ADR-0024 "Validation" — a sign the
    ///   two requests landed on different data generations); `.unresolvedGearMeasurement` if any
    ///   gear references a measurement id missing from the mobile catalogue. Either rejects the
    ///   whole `gears` update, keeping the existing on-device snapshot.
    func fetchGears() async throws -> [GearOption] {
        async let canonicalTask: ReferenceDataEnvelope<GearCanonicalDTO> = fetch(.gears)
        async let mobileTask: GearsMobileResponseDTO = fetchGearsMobile()
        let (canonical, mobile) = try await (canonicalTask, mobileTask)

        guard canonical.version == mobile.version, canonical.collectionId == mobile.collectionId else {
            throw ReferenceDataValidationError.gearViewsMismatch(
                reason: "version/collectionId differs between the canonical and mobile gears responses"
            )
        }
        let canonicalCodes = Set(canonical.items.map(\.code))
        let mobileCodes = Set(mobile.items.map(\.code))
        guard canonicalCodes == mobileCodes else {
            throw ReferenceDataValidationError.gearViewsMismatch(
                reason: "gear codes differ between the canonical and mobile gears responses"
            )
        }

        let mobileByCode = Dictionary(uniqueKeysWithValues: mobile.items.map { ($0.code, $0) })
        let measurementsById = Dictionary(
            uniqueKeysWithValues: (mobile.measurements ?? []).map { ($0.id, $0) }
        )

        return try canonical.items.map { canonicalItem in
            // Safe to force-unwrap: `mobileByCode` is keyed from `mobileCodes`, already asserted
            // equal to `canonicalCodes` above.
            guard let mobileItem = mobileByCode[canonicalItem.code] else {
                throw ReferenceDataValidationError.gearViewsMismatch(
                    reason: "gear \(canonicalItem.code) present in the canonical response but not the mobile one"
                )
            }
            return try GearOption.make(canonical: canonicalItem, mobile: mobileItem, measurementsById: measurementsById)
        }
    }

    /// Fetches and decodes the `?view=mobile` gears response alone — a private helper so
    /// `fetchGears()` above can run it concurrently with the canonical-view fetch via `async let`.
    private func fetchGearsMobile() async throws -> GearsMobileResponseDTO {
        let token = await resolvedToken()
        let request = makeReferenceDataRequest(
            baseURL: configuration.baseURL,
            dataset: .gears,
            bearerToken: token,
            view: "mobile"
        )
        return try await send(request, fallbackPath: ReferenceDataset.gears.rawValue) { data in
            try self.decoder.decode(GearsMobileResponseDTO.self, from: data)
        }
    }

    func fetchManifest() async throws -> ReferenceDataManifest {
        let token = await resolvedToken()
        let request = makeReferenceDataManifestRequest(baseURL: configuration.baseURL, bearerToken: token)
        return try await send(request, fallbackPath: "manifest") { data in
            try self.decoder.decode(ReferenceDataManifest.self, from: data)
        }
    }

    /// See `ReferenceDataFetching.fetchBlob(urlString:)`'s doc comment. Resolves `urlString`
    /// against `configuration.baseURL` when it has no scheme of its own; throws
    /// `APIError.invalidConfiguration` if the result still isn't a valid URL (a malformed manifest
    /// `url` field — never silently fetches nothing).
    func fetchBlob(urlString: String) async throws -> Data {
        guard let url = Self.resolveBlobURL(urlString, baseURL: configuration.baseURL) else {
            throw APIError.invalidConfiguration
        }
        let token = await resolvedToken()
        let request = makeReferenceDataBlobRequest(url: url, bearerToken: token)
        return try await send(request, fallbackPath: url.path) { $0 }
    }

    /// Absolute URLs (the expected shape of a manifest entry's `url` field) are used as-is; a
    /// scheme-less value is resolved against `baseURL` instead, so a relative path still works if
    /// the live API ever starts sending one.
    private static func resolveBlobURL(_ urlString: String, baseURL: URL) -> URL? {
        if let url = URL(string: urlString), url.scheme != nil {
            return url
        }
        return URL(string: urlString, relativeTo: baseURL)?.absoluteURL
    }

    func checkHealth() async throws {
        let token = await resolvedToken()
        let request = makeReferenceDataHealthRequest(baseURL: configuration.baseURL, bearerToken: token)
        _ = try await send(request, fallbackPath: "health") { _ in () }
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
    var vessels: [VesselOption] = []
    var vessel: VesselOption?
    var species: [SpeciesOption] = []
    var speciesItem: SpeciesOption?
    var ports: [PortOption] = []
    var portItem: PortOption?
    var gears: [GearOption] = []
    var manifest: ReferenceDataManifest?
    /// Keyed by the exact `urlString` passed to `fetchBlob(urlString:)` — mirrors a manifest
    /// entry's `url` field. See ADR-0024 "Map data".
    var blobsByURLString: [String: Data] = [:]
    var error: APIError?

    // Relies on Swift's synthesised memberwise initializer (every stored property above has a
    // default) rather than a hand-written `init` repeating all 8 parameters, which SonarCloud
    // flags as S107 "too many parameters" — see swift-swiftui.instructions.md.

    func fetchVessels() async throws -> [VesselOption] {
        if let error { throw error }
        return vessels
    }

    func fetchVessel(id _: String) async throws -> VesselOption {
        if let error { throw error }
        if let vessel { return vessel }
        throw APIError.response(status: 404, details: nil)
    }

    func fetchSpecies() async throws -> [SpeciesOption] {
        if let error { throw error }
        return species
    }

    func fetchSpecies(id _: String) async throws -> SpeciesOption {
        if let error { throw error }
        if let speciesItem { return speciesItem }
        throw APIError.response(status: 404, details: nil)
    }

    func fetchPorts() async throws -> [PortOption] {
        if let error { throw error }
        return ports
    }

    func fetchPort(id _: String) async throws -> PortOption {
        if let error { throw error }
        if let portItem { return portItem }
        throw APIError.response(status: 404, details: nil)
    }

    func fetchGears() async throws -> [GearOption] {
        if let error { throw error }
        return gears
    }

    func fetchManifest() async throws -> ReferenceDataManifest {
        if let error { throw error }
        if let manifest { return manifest }
        throw APIError.response(status: 503, details: nil)
    }

    func fetchBlob(urlString: String) async throws -> Data {
        if let error { throw error }
        if let data = blobsByURLString[urlString] { return data }
        throw APIError.response(status: 404, details: nil)
    }

    func checkHealth() async throws {
        if let error { throw error }
    }
}

/// Always-failing double used by `ReferenceDataSyncCoordinator.make(store:connectivityMonitor:)`
/// when this launch's `APIConfiguration()` itself throws (a misconfigured `Info.plist` —
/// see ADR-0020 §2) — there is no valid base URL to build a `RemoteReferenceDataClient` with. Every
/// method throws `APIError.invalidConfiguration` so `ReferenceDataSyncService.sync()` reports every
/// dataset as `.failed` uniformly (surfacing `SyncErrorBanner`) instead of crashing app launch.
nonisolated struct FailingReferenceDataClient: ReferenceDataFetching {
    func fetchVessels() async throws -> [VesselOption] { throw APIError.invalidConfiguration }
    func fetchVessel(id _: String) async throws -> VesselOption { throw APIError.invalidConfiguration }
    func fetchSpecies() async throws -> [SpeciesOption] { throw APIError.invalidConfiguration }
    func fetchSpecies(id _: String) async throws -> SpeciesOption { throw APIError.invalidConfiguration }
    func fetchPorts() async throws -> [PortOption] { throw APIError.invalidConfiguration }
    func fetchPort(id _: String) async throws -> PortOption { throw APIError.invalidConfiguration }
    func fetchGears() async throws -> [GearOption] { throw APIError.invalidConfiguration }
    func fetchManifest() async throws -> ReferenceDataManifest { throw APIError.invalidConfiguration }
    func fetchBlob(urlString _: String) async throws -> Data { throw APIError.invalidConfiguration }
    func checkHealth() async throws { throw APIError.invalidConfiguration }
}
