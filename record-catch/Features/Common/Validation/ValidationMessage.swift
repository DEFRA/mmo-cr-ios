import Foundation

/// A localisable validation error: a String Catalog key plus any positional arguments it needs.
///
/// Most inline errors in the app are static copy ("Select a port from the list"), for which a bare
/// key is enough — see the existing `nonisolated enum …Validation { static func errorKey(...) ->
/// String? }` pattern used across the "Create a catch record" journey. Some rules are
/// parameterised (e.g. "Date you left for your trip must be on or after 24 July 2025", "Weight for
/// Atlantic cod (COD) must be more than 0kg"), so this type generalises that pattern without
/// breaking the existing bare-key call sites: `errorKey: String?` APIs keep working unchanged, and
/// a bare key trivially becomes a `ValidationMessage` with no arguments.
///
/// `Equatable`/`Sendable` so it can be compared in tests and safely produced off the main actor by
/// pure validators, mirroring the other value types in the "Create a catch record" journey.
nonisolated struct ValidationMessage: Equatable, Sendable {
    /// The String Catalog key for the message.
    let key: String
    /// Positional arguments substituted into the localised string via `String(format:)`. Empty for
    /// static copy.
    let arguments: [String]

    init(_ key: String, arguments: [String] = []) {
        self.key = key
        self.arguments = arguments
    }
}

extension AppLanguageStore {
    /// Resolves a `ValidationMessage` in the currently selected language, substituting its
    /// arguments when present. Mirrors `localized(_:count:)`.
    func localized(_ message: ValidationMessage) -> String {
        let format = localized(message.key)
        guard !message.arguments.isEmpty else { return format }
        return String(format: format, arguments: message.arguments)
    }
}
