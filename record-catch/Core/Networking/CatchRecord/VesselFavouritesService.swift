//
//  VesselFavouritesService.swift
//  record-catch
//
//  The Catch Recording Service's vessel favourites connector (gears/species/ports) — ADR-0025.
//  Mirrors `CatchRecordService.swift`'s structure exactly; see that file's doc comment for the
//  shared architecture. **Not yet wired to anything** — the app's existing favourites providers
//  (`FavouriteGearProviding`/`FavouriteSpeciesProviding`/`FavouritePortsProviding`, ADR-0004) remain
//  on-device/local for this change; moving them to be server-backed is a separate, future piece of
//  work (see ADR-0025 "Out of scope").
//

import Foundation

/// The 6 in-scope vessel favourites operations (list/add/remove, ×3 for gears/species/ports).
nonisolated protocol VesselFavouritesServicing: Sendable {
    func listFavouriteGears(vesselId: String) async throws -> FavouriteGearsResponseDTO
    func addFavouriteGear(vesselId: String, gearId: String, idempotencyKey: String?) async throws -> FavouriteGearsResponseDTO
    func removeFavouriteGear(vesselId: String, gearId: String) async throws

    func listFavouriteSpecies(vesselId: String) async throws -> FavouriteSpeciesResponseDTO
    func addFavouriteSpecies(vesselId: String, speciesId: String, idempotencyKey: String?) async throws -> FavouriteSpeciesResponseDTO
    func removeFavouriteSpecies(vesselId: String, speciesId: String) async throws

    func listFavouritePorts(vesselId: String) async throws -> FavouritePortsResponseDTO
    func addFavouritePort(vesselId: String, portId: String, idempotencyKey: String?) async throws -> FavouritePortsResponseDTO
    func removeFavouritePort(vesselId: String, portId: String) async throws
}

/// Production implementation.
nonisolated struct VesselFavouritesService: VesselFavouritesServicing {
    private let transport: CatchRecordTransport
    private let configuration: APIConfiguration
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        httpClient: HTTPPerforming,
        configuration: APIConfiguration,
        tokenProvider: AuthTokenProviding,
        logger: NetworkLogger = NetworkLogger()
    ) {
        self.transport = CatchRecordTransport(httpClient: httpClient, tokenProvider: tokenProvider, logger: logger)
        self.configuration = configuration
        self.decoder = CatchRecordTransport.makeDecoder()
        self.encoder = CatchRecordTransport.makeEncoder()
    }

    func listFavouriteGears(vesselId: String) async throws -> FavouriteGearsResponseDTO {
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(route: .listFavouriteGears(vesselId: vesselId), baseURL: configuration.baseURL, bearerToken: token)
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(FavouriteGearsResponseDTO.self, from: $0) }
    }

    func addFavouriteGear(vesselId: String, gearId: String, idempotencyKey: String? = nil) async throws -> FavouriteGearsResponseDTO {
        try CatchRecordRequestValidation.validateIdempotencyKey(idempotencyKey)
        let token = await transport.resolvedToken()
        let request = try makeCatchRecordRequest(
            route: .addFavouriteGear(vesselId: vesselId),
            baseURL: configuration.baseURL,
            body: FavouriteGearPayload(gearId: gearId),
            bearerToken: token,
            idempotencyKey: idempotencyKey,
            encoder: encoder
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(FavouriteGearsResponseDTO.self, from: $0) }
    }

    func removeFavouriteGear(vesselId: String, gearId: String) async throws {
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(route: .removeFavouriteGear(vesselId: vesselId, gearId: gearId), baseURL: configuration.baseURL, bearerToken: token)
        try await transport.sendExpectingNoContent(request, decoder: decoder)
    }

    func listFavouriteSpecies(vesselId: String) async throws -> FavouriteSpeciesResponseDTO {
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(route: .listFavouriteSpecies(vesselId: vesselId), baseURL: configuration.baseURL, bearerToken: token)
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(FavouriteSpeciesResponseDTO.self, from: $0) }
    }

    func addFavouriteSpecies(vesselId: String, speciesId: String, idempotencyKey: String? = nil) async throws -> FavouriteSpeciesResponseDTO {
        try CatchRecordRequestValidation.validateIdempotencyKey(idempotencyKey)
        let token = await transport.resolvedToken()
        let request = try makeCatchRecordRequest(
            route: .addFavouriteSpecies(vesselId: vesselId),
            baseURL: configuration.baseURL,
            body: FavouriteSpeciesPayload(speciesId: speciesId),
            bearerToken: token,
            idempotencyKey: idempotencyKey,
            encoder: encoder
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(FavouriteSpeciesResponseDTO.self, from: $0) }
    }

    func removeFavouriteSpecies(vesselId: String, speciesId: String) async throws {
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(route: .removeFavouriteSpecies(vesselId: vesselId, speciesId: speciesId), baseURL: configuration.baseURL, bearerToken: token)
        try await transport.sendExpectingNoContent(request, decoder: decoder)
    }

    func listFavouritePorts(vesselId: String) async throws -> FavouritePortsResponseDTO {
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(route: .listFavouritePorts(vesselId: vesselId), baseURL: configuration.baseURL, bearerToken: token)
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(FavouritePortsResponseDTO.self, from: $0) }
    }

    func addFavouritePort(vesselId: String, portId: String, idempotencyKey: String? = nil) async throws -> FavouritePortsResponseDTO {
        try CatchRecordRequestValidation.validateIdempotencyKey(idempotencyKey)
        let token = await transport.resolvedToken()
        let request = try makeCatchRecordRequest(
            route: .addFavouritePort(vesselId: vesselId),
            baseURL: configuration.baseURL,
            body: FavouritePortPayload(portId: portId),
            bearerToken: token,
            idempotencyKey: idempotencyKey,
            encoder: encoder
        )
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode(FavouritePortsResponseDTO.self, from: $0) }
    }

    func removeFavouritePort(vesselId: String, portId: String) async throws {
        let token = await transport.resolvedToken()
        let request = makeCatchRecordRequest(route: .removeFavouritePort(vesselId: vesselId, portId: portId), baseURL: configuration.baseURL, bearerToken: token)
        try await transport.sendExpectingNoContent(request, decoder: decoder)
    }
}

/// Fixture-backed double for future call sites/tests.
nonisolated struct StubVesselFavouritesService: VesselFavouritesServicing {
    var gearsResponse: FavouriteGearsResponseDTO?
    var speciesResponse: FavouriteSpeciesResponseDTO?
    var portsResponse: FavouritePortsResponseDTO?
    var error: APIError?

    func listFavouriteGears(vesselId: String) async throws -> FavouriteGearsResponseDTO {
        if let error { throw error }
        return gearsResponse ?? FavouriteGearsResponseDTO(vesselId: vesselId, favouriteGearIds: [])
    }

    func addFavouriteGear(vesselId: String, gearId: String, idempotencyKey: String? = nil) async throws -> FavouriteGearsResponseDTO {
        if let error { throw error }
        return gearsResponse ?? FavouriteGearsResponseDTO(vesselId: vesselId, favouriteGearIds: [gearId])
    }

    func removeFavouriteGear(vesselId: String, gearId: String) async throws {
        if let error { throw error }
    }

    func listFavouriteSpecies(vesselId: String) async throws -> FavouriteSpeciesResponseDTO {
        if let error { throw error }
        return speciesResponse ?? FavouriteSpeciesResponseDTO(vesselId: vesselId, favouriteSpeciesIds: [])
    }

    func addFavouriteSpecies(vesselId: String, speciesId: String, idempotencyKey: String? = nil) async throws -> FavouriteSpeciesResponseDTO {
        if let error { throw error }
        return speciesResponse ?? FavouriteSpeciesResponseDTO(vesselId: vesselId, favouriteSpeciesIds: [speciesId])
    }

    func removeFavouriteSpecies(vesselId: String, speciesId: String) async throws {
        if let error { throw error }
    }

    func listFavouritePorts(vesselId: String) async throws -> FavouritePortsResponseDTO {
        if let error { throw error }
        return portsResponse ?? FavouritePortsResponseDTO(vesselId: vesselId, favouritePortIds: [])
    }

    func addFavouritePort(vesselId: String, portId: String, idempotencyKey: String? = nil) async throws -> FavouritePortsResponseDTO {
        if let error { throw error }
        return portsResponse ?? FavouritePortsResponseDTO(vesselId: vesselId, favouritePortIds: [portId])
    }

    func removeFavouritePort(vesselId: String, portId: String) async throws {
        if let error { throw error }
    }
}

/// Used whenever the Catch Recording Service's base URL is not yet configured for this stage (see
/// `CatchRecordServicesFactory`/ADR-0025).
nonisolated struct FailingVesselFavouritesService: VesselFavouritesServicing {
    func listFavouriteGears(vesselId: String) async throws -> FavouriteGearsResponseDTO { throw APIError.invalidConfiguration }
    func addFavouriteGear(vesselId: String, gearId: String, idempotencyKey: String? = nil) async throws -> FavouriteGearsResponseDTO { throw APIError.invalidConfiguration }
    func removeFavouriteGear(vesselId: String, gearId: String) async throws { throw APIError.invalidConfiguration }
    func listFavouriteSpecies(vesselId: String) async throws -> FavouriteSpeciesResponseDTO { throw APIError.invalidConfiguration }
    func addFavouriteSpecies(vesselId: String, speciesId: String, idempotencyKey: String? = nil) async throws -> FavouriteSpeciesResponseDTO { throw APIError.invalidConfiguration }
    func removeFavouriteSpecies(vesselId: String, speciesId: String) async throws { throw APIError.invalidConfiguration }
    func listFavouritePorts(vesselId: String) async throws -> FavouritePortsResponseDTO { throw APIError.invalidConfiguration }
    func addFavouritePort(vesselId: String, portId: String, idempotencyKey: String? = nil) async throws -> FavouritePortsResponseDTO { throw APIError.invalidConfiguration }
    func removeFavouritePort(vesselId: String, portId: String) async throws { throw APIError.invalidConfiguration }
}
