import Foundation

/// Pure, static validation for the Add-port screen.
///
/// Kept out of the view model/view so the rule is trivially unit-testable with no view host.
nonisolated enum AddPortValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when a port has been selected
    /// from the list.
    static func errorKey(for selection: PortOption?) -> String? {
        selection == nil ? "catchRecord.addPort.validation.none" : nil
    }
}
