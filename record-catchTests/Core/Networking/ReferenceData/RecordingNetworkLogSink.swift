//
//  RecordingNetworkLogSink.swift
//  record-catchTests
//
//  Captures every logged line for the "never logs the token/headers" security assertion (see
//  security.instructions.md and ADR-0018 §"Structured logging").
//

import Foundation
@testable import record_catch

final class RecordingNetworkLogSink: NetworkLogSink, @unchecked Sendable {
    private(set) var messages: [String] = []

    init() {
        // Intentionally empty: `messages` is already initialised to an empty array above.
    }

    func log(_ message: String) {
        messages.append(message)
    }
}
