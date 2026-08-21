import Foundation

/// Supplies the signed-in user's account details for the "Manage your account" screen.
///
/// Offline-first / local-only for this phase — no networking. See docs/design-specs/manage-account.md.
///
/// - TODO: Replace `StubAccountProvider` with a real, API-backed implementation once an account
///   service exists (a future ADR); every "Change" seam on `ManageAccountViewModel` stays inert
///   until that real destination/service exists too.
nonisolated protocol AccountProviding: Sendable {
    /// The current user's account details.
    func currentAccount() -> Account
}

/// Fixed, in-memory stub — always returns `Account.fixture` (or an injected value for
/// tests/previews that need a different account).
nonisolated struct StubAccountProvider: AccountProviding {
    private let account: Account

    init(account: Account = .fixture) {
        self.account = account
    }

    func currentAccount() -> Account {
        account
    }
}
