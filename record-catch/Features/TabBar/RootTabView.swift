//
//  RootTabView.swift
//  record-catch
//
//  Root `TabView` hosting Home / Notifications / Settings, bound to `AppTabRouter`
//  (see ADR-0006). Home wraps the existing, unmodified `CatchRecordHostView` — the
//  "Create a catch record" journey (ADR-0003) is completely unchanged.
//

import SwiftUI

struct RootTabView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(AppTabRouter.self) private var tabRouter

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

            NavigationStack {
                SettingsView()
            }
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
