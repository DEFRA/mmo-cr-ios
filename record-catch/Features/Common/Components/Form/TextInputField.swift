import SwiftUI

struct TextInputField: View {
    let label: String
    let hint: String?
    let placeholder: String
    let isSecure: Bool
    let isRequired: Bool
    let keyboardType: UIKeyboardType
    let textInputAutocapitalization: TextInputAutocapitalization
    let autocorrectionDisabled: Bool
    @Binding var text: String
    var didAttemptSubmit: Bool = false
    var errorMessage: String?

    @FocusState private var isFocused: Bool
    @State private var hasBlurred = false

    init(
        label: String,
        hint: String? = nil,
        placeholder: String = "",
        isSecure: Bool = false,
        isRequired: Bool = true,
        keyboardType: UIKeyboardType = .default,
        textInputAutocapitalization: TextInputAutocapitalization = .sentences,
        autocorrectionDisabled: Bool = false,
        text: Binding<String>,
        didAttemptSubmit: Bool = false,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.hint = hint
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.isRequired = isRequired
        self.keyboardType = keyboardType
        self.textInputAutocapitalization = textInputAutocapitalization
        self.autocorrectionDisabled = autocorrectionDisabled
        _text = text
        self.didAttemptSubmit = didAttemptSubmit
        self.errorMessage = errorMessage
    }

    private var shouldShowError: Bool {
        Self.shouldShowRequiredError(
            text: text,
            didAttemptSubmit: didAttemptSubmit,
            hasBlurred: hasBlurred,
            isRequired: isRequired
        )
    }

    private var resolvedErrorMessage: String {
        if let errorMessage {
            return errorMessage
        }

        return "Enter \(label.lowercased())"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)

            if let hint {
                ParagraphText(text: hint, isHint: true)
            }

            inputField

            if shouldShowError {
                Text(resolvedErrorMessage)
                    .font(AppTypography.error)
                    .foregroundStyle(AppColors.errorRed)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                hasBlurred = true
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
                .textContentType(.password)
                .formInputStyle(showError: shouldShowError)
                .focused($isFocused)
        } else {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .formInputStyle(showError: shouldShowError)
                .focused($isFocused)
        }
    }

    static func shouldShowRequiredError(text: String, didAttemptSubmit: Bool, hasBlurred: Bool, isRequired: Bool) -> Bool {
        guard isRequired else {
            return false
        }

        return (didAttemptSubmit || hasBlurred) && isBlank(text)
    }

    static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private extension View {
    func formInputStyle(showError: Bool) -> some View {
        self
            .font(AppTypography.bodySmall)
            .padding(.horizontal, AppSpacing.small)
            .frame(height: AppControlSize.dateFieldHeight)
            .overlay(
                Rectangle()
                    .stroke(showError ? AppColors.errorRed : AppColors.borderStrong, lineWidth: 1)
            )
    }
}

#Preview {
    @Previewable @State var email = ""
    @Previewable @State var password = ""

    return VStack(alignment: .leading, spacing: AppSpacing.medium) {
        TextInputField(
            label: "Email address",
            textInputAutocapitalization: .never,
            autocorrectionDisabled: true,
            text: $email,
            didAttemptSubmit: true
        )

        TextInputField(
            label: "Password",
            isSecure: true,
            textInputAutocapitalization: .never,
            autocorrectionDisabled: true,
            text: $password,
            didAttemptSubmit: true
        )
    }
    .padding()
}
