import Foundation

/// The screens reachable from within the Settings tab's own navigation stack.
///
/// A typed, homogeneous route enum backing `SettingsRouter.path` — mirrors `CatchRecordRoute`
/// (see ADR-0003 for why this is preferred over `NavigationPath` here: testability,
/// homogeneity, open-endedness). See docs/adr/0007-settings-tab-navigation.md.
enum SettingsRoute: Hashable {
    /// The "Manage your account" screen, reached from Settings' "My account" link.
    case manageAccount
}
