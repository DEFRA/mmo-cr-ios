//
//  AppTabRouterTests.swift
//  record-catchTests
//
//  Unit tests for `AppTabRouter`, the tab-selection model behind the root `TabView`
//  (see ADR-0006). Deliberately free of any View type, so it's tested directly.
//

import XCTest
@testable import record_catch

@MainActor
final class AppTabRouterTests: XCTestCase {

    func test_default_selectionIsHome() {
        let sut = AppTabRouter()
        XCTAssertEqual(sut.selection, .home)
    }

    func test_init_canSeedNonDefaultSelection() {
        let sut = AppTabRouter(selection: .settings)
        XCTAssertEqual(sut.selection, .settings)
    }

    func test_selection_transitionsBetweenAllTabs() {
        let sut = AppTabRouter()

        sut.selection = .notifications
        XCTAssertEqual(sut.selection, .notifications)

        sut.selection = .settings
        XCTAssertEqual(sut.selection, .settings)

        sut.selection = .home
        XCTAssertEqual(sut.selection, .home)
    }

    func test_appTab_equality() {
        XCTAssertEqual(AppTab.home, AppTab.home)
        XCTAssertNotEqual(AppTab.home, AppTab.notifications)
        XCTAssertNotEqual(AppTab.notifications, AppTab.settings)
    }

    func test_appTab_allCases() {
        XCTAssertEqual(AppTab.allCases, [.home, .notifications, .settings])
    }
}
