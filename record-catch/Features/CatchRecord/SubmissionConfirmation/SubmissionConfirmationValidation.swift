import Foundation

/// Pure, static validation for the "Confirmation" screen's single confirmation checkbox.
enum SubmissionConfirmationValidation {
    /// Returns the String Catalog key for the inline error, or `nil` when `isConfirmed` is valid.
    static func errorKey(for isConfirmed: Bool) -> String? {
        isConfirmed ? nil : "catchRecord.submissionConfirmation.validation.none"
    }
}
