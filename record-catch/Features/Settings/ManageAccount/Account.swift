import Foundation

/// The signed-in user's account details, as shown on the "Manage your account" screen's
/// "Your details" section (see docs/design-specs/manage-account.md).
///
/// **This model carries mock PII for this UI-only phase.** The literal values live in exactly
/// one place — `Account.fixture` below — so previews/tests always use neutral placeholders and
/// no field value is ever hard-coded again elsewhere (e.g. directly in a view) or logged.
struct Account: Equatable, Sendable {
    let firstName: String
    let lastName: String
    let address: String
    let email: String
    let contactNumber: String

    /// The single stub fixture backing `StubAccountProvider`. Deliberately the **only** place
    /// this mock PII is written in source — do not copy these literal values elsewhere.
    ///
    /// - TODO: Replace with a real account API/service once one exists (a future ADR); the
    ///   `AccountProviding` seam below already isolates this screen from that future change.
    static let fixture = Account(
        firstName: "James",
        lastName: "Wilson",
        address: "Harbour View House, The Quay, Peterhead, AB42 1BY",
        email: "james.wilson@company.co.uk",
        contactNumber: "07700 900123"
    )

    /// A neutral, non-PII placeholder for previews/tests that don't need `Account.fixture`'s
    /// mock personal data (e.g. layout-focused previews).
    static let placeholder = Account(
        firstName: "First name",
        lastName: "Last name",
        address: "Address line",
        email: "name@example.com",
        contactNumber: "00000 000000"
    )
}
