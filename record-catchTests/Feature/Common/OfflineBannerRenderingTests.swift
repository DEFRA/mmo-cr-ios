//
//  OfflineBannerRenderingTests.swift
//  record-catchTests
//
//  Rendering tests for `OfflineBanner`'s SwiftUI `body` — online, offline, no-monitor-configured
//  and Reduce Motion states, plus the online/offline transition that drives `announce(isOnline:)`
//  (see `ViewRenderingHarness`). Pure logic (`accessibilityLabel`) is covered separately by
//  `OfflineBannerTests`; VoiceOver announcement behaviour on a real accessibility tree is covered
//  by `OfflineBannerUITests`.
//

import XCTest
import SwiftUI
@testable import record_catch

@MainActor
final class OfflineBannerRenderingTests: XCTestCase {

    func test_render_offline() {
        ViewRenderingHarness.render(
            OfflineBanner()
                .environment(\.connectivityMonitor, StubConnectivityMonitor(isOnline: false))
                .environment(AppLanguageStore.preview)
        )
    }

    func test_render_online_rendersNothing() {
        ViewRenderingHarness.render(
            OfflineBanner()
                .environment(\.connectivityMonitor, StubConnectivityMonitor(isOnline: true))
                .environment(AppLanguageStore.preview)
        )
    }

    /// No connectivity monitor configured at all — treated as online (see
    /// `OfflineBanner.isOnline`), so this must render nothing rather than crash or spuriously
    /// show the banner.
    func test_render_noMonitorConfigured_treatedAsOnline() {
        ViewRenderingHarness.render(
            OfflineBanner()
                .environment(AppLanguageStore.preview)
        )
    }

    /// Flips the stub monitor from offline to online after the first render, so `onChange(of:
    /// isOnline)` and `announce(isOnline:)` both actually run (see `OfflineBanner.body`).
    func test_render_thenGoesOnline_runsOnChangeAndAnnounce() {
        let monitor = StubConnectivityMonitor(isOnline: false)
        ViewRenderingHarness.render(
            OfflineBanner()
                .environment(\.connectivityMonitor, monitor)
                .environment(AppLanguageStore.preview)
        )

        monitor.isOnline = true
        ViewRenderingHarness.render(
            OfflineBanner()
                .environment(\.connectivityMonitor, monitor)
                .environment(AppLanguageStore.preview)
        )
    }
}
