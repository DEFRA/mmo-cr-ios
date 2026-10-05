//
//  OfflineBannerTests.swift
//  record-catchTests
//
//  Unit tests for `OfflineBanner`'s pure, view-host-independent logic (see ADR-0019). Rendering
//  and VoiceOver-announcement behaviour are covered by `OfflineBannerUITests` instead, which can
//  observe the real accessibility tree.
//

import XCTest
@testable import record_catch

final class OfflineBannerTests: XCTestCase {

    func test_accessibilityLabel_composesTagAndMessage() {
        let label = OfflineBanner.accessibilityLabel(
            tag: "Offline",
            message: "You can still record your catch. Your record will be saved and sent when you're back online."
        )
        XCTAssertEqual(
            label,
            "Offline, You can still record your catch. Your record will be saved and sent when you're back online."
        )
    }

    func test_accessibilityLabel_welshTagAndMessage() {
        let label = OfflineBanner.accessibilityLabel(tag: "All-lein", message: "Neges")
        XCTAssertEqual(label, "All-lein, Neges")
    }
}
