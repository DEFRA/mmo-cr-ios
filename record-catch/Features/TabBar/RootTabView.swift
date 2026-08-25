//
//  RootTabView.swift
//  record-catch
//
//  Root `TabView` hosting Home / Notifications / Settings, bound to `AppTabRouter`
//  (see ADR-0006). Home wraps the existing, unmodified `CatchRecordHostView` — the
//  "Create a catch record" journey (ADR-0003) is completely unchanged. The Settings tab owns
//  its own `SettingsRouter`/`NavigationStack` (see ADR-0007) so "My account" can push
//  "Manage your account" while the tab bar stays visible.
//

import SwiftUI

struct RootTabView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(AppTabRouter.self) private var tabRouter
    @State private var settingsRouter: SettingsRouter

    /// - Parameter initialSettingsRoute: optional route to seed the Settings tab's stack with at
    ///   launch, used by UI tests to jump straight to "Manage your account"
    ///   (`-uiTestManageAccount`), mirroring `CatchRecordHostView(initialRoute:)`.
    init(initialSettingsRoute: SettingsRoute? = nil) {
        let router = SettingsRouter()
        if let initialSettingsRoute {
            router.push(initialSettingsRoute)
        }
        _settingsRouter = State(wrappedValue: router)
    }

    var body: some View {
        @Bindable var tabRouter = tabRouter
        TabView(selection: $tabRouter.selection) {
            CatchRecordHostView()
                .tabItem {
                    Label(languageStore.localized("tabBar.home"), systemImage: tabRouter.selection == .home ? "house.fill" : "house")
                        .accessibilityIdentifier("TabBar.home")
                }
                .tag(AppTab.home)

            NavigationStack {
                NotificationsPlaceholderView()
            }
            .tabItem {
                Label(languageStore.localized("tabBar.notifications"), systemImage: tabRouter.selection == .notifications ? "bell.fill" : "bell")
                    .accessibilityIdentifier("TabBar.notifications")
            }
            .tag(AppTab.notifications)

            settingsTab
                .tabItem {
                    Label(languageStore.localized("tabBar.settings"), systemImage: tabRouter.selection == .settings ? "gearshape.fill" : "gearshape")
                        .accessibilityIdentifier("TabBar.settings")
                }
                .tag(AppTab.settings)
        }
        .tint(AppColors.tabItemSelected)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    /// The Settings tab's own `NavigationStack`, bound to `settingsRouter` (see ADR-0007).
    /// Deliberately does **not** apply `.toolbar(.hidden, for: .tabBar)` to
    /// `ManageAccountView` — unlike the "Create a catch record" journey, the design keeps the
    /// tab bar visible on this pushed screen.
    private var settingsTab: some View {
        NavigationStack(path: Binding(get: { settingsRouter.path }, set: { settingsRouter.setPath($0) })) {
            SettingsView(router: settingsRouter)
                .navigationDestination(for: SettingsRoute.self) { route in
                    destination(for: route)
                }
        }
        .environment(\.headerNavigator, settingsRouter)
    }

    @ViewBuilder
    private func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .manageAccount:
            ManageAccountView()
        }
    }

    /// Applies the AA-contrast unselected-tab colour (`AppColors.tabItemUnselected`) via
    /// `UITabBarAppearance`, since SwiftUI's `TabView` has no direct unselected-item-colour
    /// modifier — only `.tint(_:)` for the selected item.
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.background)
        let unselectedColor = UIColor(AppColors.tabItemUnselected)
        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview("English") {
    RootTabView()
        .environment(AppLanguageStore.preview)
        .environment(AppTabRouter())
}

#Preview("Welsh") {
    RootTabView()
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
        .environment(AppTabRouter())
}
