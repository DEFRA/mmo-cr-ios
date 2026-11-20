//
//  InlineWarningTextTests.swift
//  record-catchTests
//
//  Rendering coverage for `InlineWarningText`'s SwiftUI `body` — see `ViewRenderingHarness` and
//  `WarningBoxTests` (which already covers the shared `WarningBox.accessibilityLabel` composition
//  this view reuses).
//

import XCTest
import SwiftUI
@testable import record_catch

@MainActor
final class InlineWarningTextTests: XCTestCase {

    func test_render_english() {
        ViewRenderingHarness.render(
            InlineWarningText(tagKey: "home.warning.tag", messageKey: "home.warning.message")
                .environment(AppLanguageStore.preview)
        )
    }

    func test_render_welsh() {
        let store = AppLanguageStore.preview
        store.language = .welsh
        ViewRenderingHarness.render(
            InlineWarningText(tagKey: "home.warning.tag", messageKey: "home.warning.message")
                .environment(store)
        )
    }

    func test_render_maxDynamicType() {
        ViewRenderingHarness.render(
            InlineWarningText(tagKey: "home.warning.tag", messageKey: "home.warning.message")
                .environment(AppLanguageStore.preview)
                .environment(\.dynamicTypeSize, .accessibility5)
        )
    }
}
