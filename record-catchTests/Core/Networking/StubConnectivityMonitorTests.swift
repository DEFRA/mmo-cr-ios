//
//  StubConnectivityMonitorTests.swift
//  record-catchTests
//
//  Minimal coverage for the test/preview double itself (see ADR-0019), so a regression in its
//  trivial settable behaviour would be caught rather than silently breaking every other test or
//  preview that depends on it.
//

import XCTest
@testable import record_catch

@MainActor
final class StubConnectivityMonitorTests: XCTestCase {

    func test_init_setsInitialIsOnlineValue() {
        let online = StubConnectivityMonitor(isOnline: true)
        XCTAssertTrue(online.isOnline)

        let offline = StubConnectivityMonitor(isOnline: false)
        XCTAssertFalse(offline.isOnline)
    }

    func test_isOnline_isSettable_forDrivingPreviewsAndTests() {
        let monitor = StubConnectivityMonitor(isOnline: true)
        monitor.isOnline = false
        XCTAssertFalse(monitor.isOnline)
    }
}
