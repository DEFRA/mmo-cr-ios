import Foundation

/// The two things a user can do with an existing draft (unsent) catch record.
enum DraftActionOption: String, CaseIterable, Identifiable {
    case complete
    case delete

    var id: String { rawValue }
}

/// Pure, static validation for the Draft action screen.
enum DraftActionValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when `selection` is valid.
    static func errorKey(for selection: DraftActionOption?) -> String? {
        selection == nil ? "catchRecord.draftAction.validation.none" : nil
    }
}
