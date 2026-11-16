//
//  CatchRecordPlatformService.swift
//  record-catch
//
//  The Catch Recording Service's two unauthenticated platform routes: `/health` (liveness probe)
//  and `/example` (a generic service-skeleton template endpoint, not part of the Catch Recording
//  domain — kept in scope only as a lightweight "can this app reach the service at all" check, per
//  ADR-0025).
//

import Foundation

nonisolated protocol CatchRecordPlatformServicing: Sendable {
    /// Pings `GET /health`. Succeeds (returns) on any 2xx response and throws `APIError` otherwise.
    func checkHealth() async throws
    /// Fetches `GET /example` — a template-skeleton endpoint with no fixed response schema (see
    /// `ExampleEntity`). Returned as raw JSON since the service's spec does not constrain its shape.
    func listExampleData() async throws -> [ExampleEntity]
}

/// Raw, schema-less document from the `/example` route's `example-data` collection — the spec
/// declares `additionalProperties: true` with no further structure.
nonisolated struct ExampleEntity: Codable, Equatable, Sendable {
    let properties: [String: AnyCodableValue]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        properties = try container.decode([String: AnyCodableValue].self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(properties)
    }
}

/// A minimal `Codable` box for an arbitrary JSON value — enough to round-trip `/example`'s
/// unconstrained documents without modelling a fixed schema for a route explicitly documented as
/// "not part of the Catch Recording domain" (see the spec's own tag description).
nonisolated enum AnyCodableValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    indirect case array([AnyCodableValue])
    indirect case object([String: AnyCodableValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AnyCodableValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyCodableValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

nonisolated struct CatchRecordPlatformService: CatchRecordPlatformServicing {
    private let transport: CatchRecordTransport
    private let configuration: APIConfiguration
    private let decoder: JSONDecoder

    init(
        httpClient: HTTPPerforming,
        configuration: APIConfiguration,
        tokenProvider: AuthTokenProviding,
        logger: NetworkLogger = NetworkLogger()
    ) {
        self.transport = CatchRecordTransport(httpClient: httpClient, tokenProvider: tokenProvider, logger: logger)
        self.configuration = configuration
        self.decoder = CatchRecordTransport.makeDecoder()
    }

    func checkHealth() async throws {
        let request = makeCatchRecordRequest(route: .health, baseURL: configuration.baseURL, bearerToken: nil)
        try await transport.sendExpectingNoContent(request, decoder: decoder)
    }

    func listExampleData() async throws -> [ExampleEntity] {
        let request = makeCatchRecordRequest(route: .listExampleData, baseURL: configuration.baseURL, bearerToken: nil)
        return try await transport.send(request, decoder: decoder) { try self.decoder.decode([ExampleEntity].self, from: $0) }
    }
}

nonisolated struct StubCatchRecordPlatformService: CatchRecordPlatformServicing {
    var exampleData: [ExampleEntity] = []
    var error: APIError?

    func checkHealth() async throws {
        if let error { throw error }
    }

    func listExampleData() async throws -> [ExampleEntity] {
        if let error { throw error }
        return exampleData
    }
}

nonisolated struct FailingCatchRecordPlatformService: CatchRecordPlatformServicing {
    func checkHealth() async throws { throw APIError.invalidConfiguration }
    func listExampleData() async throws -> [ExampleEntity] { throw APIError.invalidConfiguration }
}
