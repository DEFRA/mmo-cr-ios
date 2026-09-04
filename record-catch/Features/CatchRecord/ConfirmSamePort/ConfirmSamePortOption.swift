import Foundation

/// The Yes/No answer on the "Was `<port>` your departure and return port?" screen.
enum ConfirmSamePortOption: String, CaseIterable, Identifiable {
    case yes
    case no

    var id: String { rawValue }
}

/// Pure, static validation for the "Was `<port>` your departure and return port?" screen.
enum ConfirmSamePortValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when `selection` is valid.
    static func errorKey(for selection: ConfirmSamePortOption?) -> String? {
        selection == nil ? "catchRecord.confirmSamePort.validation.none" : nil
    }
}
