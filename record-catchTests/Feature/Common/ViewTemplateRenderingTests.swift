//
//  ViewTemplateRenderingTests.swift
//  record-catchTests
//
//  Rendering tests for `ViewTemplate`'s SwiftUI `body` — with and without a `warning` box, and
//  with an empty title (opting a screen out of the shared heading slot) — see `ViewTemplate.body`
//  and `ViewRenderingHarness`.
//

import XCTest
import SwiftUI
@testable import record_catch

@MainActor
final class ViewTemplateRenderingTests: XCTestCase {

    func test_render_withTitle_noWarning() {
        ViewRenderingHarness.render(
            ViewTemplate(title: "Test") {
                Text("Content")
            }
            .environment(AppLanguageStore.preview)
        )
    }

    func test_render_withEmptyTitle_omitsHeading() {
        ViewRenderingHarness.render(
            ViewTemplate(title: "") {
                Text("Content")
            }
            .environment(AppLanguageStore.preview)
        )
    }

    func test_render_withWarning() {
        ViewRenderingHarness.render(
            ViewTemplate(
                title: "Test",
                warning: WarningBox(tagKey: "home.warning.tag", messageKey: "catchRecord.submissionSaved.body")
            ) {
                Text("Content")
            }
            .environment(AppLanguageStore.preview)
        )
    }
}
