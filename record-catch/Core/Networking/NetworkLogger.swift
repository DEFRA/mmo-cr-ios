//
//  NetworkLogger.swift
//  record-catch
//
//  Structured, privacy-safe request logging (see ADR-0018 §"Structured logging" and
//  security.instructions.md's "log errors, never secrets" requirement). Only method, path,
//  status, duration and (for failures) the API's own machine-readable `errorCode`/`traceId` are
//  ever logged — never headers, the `Authorization` value, the token, or response bodies. The
//  sink is injectable so tests can assert none of that sensitive data ever appears in emitted log
//  lines.
//

import Foundation
import OSLog

/// A single, already-redacted log line's constituent fields. Deliberately excludes headers,
/// tokens and response bodies — there is no way to construct one carrying that data. `errorCode`
/// and `traceId` come only from the API's own standard error envelope (see `APIErrorDetails`),
/// never from request content, so they carry no sensitive data either.
nonisolated struct NetworkLogEntry: Sendable, Equatable {
    let method: String
    let path: String
    let statusCode: Int?
    let durationSeconds: Double
    let errorCode: String?
    let traceId: String?

    init(
        method: String,
        path: String,
        statusCode: Int?,
        durationSeconds: Double,
        errorCode: String? = nil,
        traceId: String? = nil
    ) {
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.durationSeconds = durationSeconds
        self.errorCode = errorCode
        self.traceId = traceId
    }
}

/// Sink that receives formatted log lines — injectable so a test can capture output without
/// depending on the real `OSLog` store.
nonisolated protocol NetworkLogSink: Sendable {
    func log(_ message: String)
}

/// Default sink: `OSLog`/`Logger`, subsystem `uk.gov.defra.record-catch`, category `networking`.
nonisolated struct OSLogNetworkLogSink: NetworkLogSink {
    private static let logger = Logger(subsystem: "uk.gov.defra.record-catch", category: "networking")

    func log(_ message: String) {
        Self.logger.log("\(message, privacy: .public)")
    }
}

/// Logs reference-data API requests. Never given a `URLRequest` or raw response — only the
/// fields on `NetworkLogEntry` above — so it is structurally incapable of logging a header, the
/// `Authorization` value, the token, or a response body.
nonisolated struct NetworkLogger: Sendable {
    private let sink: NetworkLogSink

    init(sink: NetworkLogSink = OSLogNetworkLogSink()) {
        self.sink = sink
    }

    func log(_ entry: NetworkLogEntry) {
        let statusDescription = entry.statusCode.map(String.init) ?? "error"
        let durationMilliseconds = Int((entry.durationSeconds * 1000).rounded())
        var message = "\(entry.method) \(entry.path) -> \(statusDescription) (\(durationMilliseconds)ms)"
        if let errorCode = entry.errorCode {
            message += " errorCode=\(errorCode)"
        }
        if let traceId = entry.traceId {
            message += " traceId=\(traceId)"
        }
        sink.log(message)
    }
}
