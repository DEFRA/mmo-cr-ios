//
//  AppTabRouter.swift
//  record-catch
//
//  Tab-selection model for the root `TabView` (see ADR-0006). Deliberately free of any View
//  types so it stays trivially unit-testable and can be seeded from launch arguments.
//

import Foundation

/// The three top-level tabs of the app's root `TabView`.
enum AppTab: String, CaseIterable, Hashable {
    case home
    case notifications
    case settings
}

/// Owns the currently-selected root tab.
///
/// Injected once (via `.environment(_:)`) at the app root and bound to `RootTabView`'s
/// `TabView(selection:)`. Kept separate from `CatchRecordRouter` (ADR-0003), which continues to
/// own only the in-journey navigation stack nested inside the Home tab.
@MainActor
@Observable
final class AppTabRouter {

    var selection: AppTab

    init(selection: AppTab = .home) {
        self.selection = selection
    }
}
