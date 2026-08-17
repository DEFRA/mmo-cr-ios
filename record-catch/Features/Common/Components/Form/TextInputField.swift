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
    let secureTextContentType: UITextContentType
    @Binding var text: String
    var didAttemptSubmit: Bool = false
    var errorMessage: String?

    @FocusState private var isFocused: Bool
    @State private var hasBlurred = false
    @State private var isSecureTextVisible = false

    /// Creates a text input field.
    ///
    /// - Note: When `isSecure == true`, the `textInputAutocapitalization` and
    ///   `autocorrectionDisabled` parameters are IGNORED — secure input always forces
    ///   `.never` capitalisation and disables autocorrection for security reasons.
    init(
        label: String,
        hint: String? = nil,
        placeholder: String = "",
        isSecure: Bool = false,
        isRequired: Bool = true,
        keyboardType: UIKeyboardType = .default,
        textInputAutocapitalization: TextInputAutocapitalization = .sentences,
        autocorrectionDisabled: Bool = false,
        secureTextContentType: UITextContentType = .password,
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
        self.secureTextContentType = secureTextContentType
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
            secureInputField
        } else {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .foregroundStyle(AppColors.textPrimary)
                .formInputStyle(showError: shouldShowError)
                .focused($isFocused)
        }
    }

    @ViewBuilder
    private var secureInputField: some View {
        HStack(spacing: AppSpacing.small) {
            Group {
                if isSecureTextVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textContentType(secureTextContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(AppColors.textPrimary)
                .focused($isFocused)
                .accessibilityIdentifier("TextInputField.secureInput")

            Button {
                isSecureTextVisible.toggle()
                // Preserve focus on the field after toggling where practical.
                // Defer to the next runloop so the SecureField/TextField swap
                // completes before we restore focus, which is more robust on device.
                Task { @MainActor in
                    isFocused = true
                }
            } label: {
                Image(systemName: isSecureTextVisible ? "eye.slash" : "eye")
                    .frame(width: AppControlSize.buttonHeight, height: AppControlSize.buttonHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tint(AppColors.govBlue)
            .accessibilityLabel(Self.passwordToggleLabel(isVisible: isSecureTextVisible))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("TextInputField.secureToggle")
        }
        .formInputStyle(showError: shouldShowError)
    }

    /// Returns the accessibility label for the show/hide password toggle.
    /// Pure and static so the security-relevant labelling can be unit tested.
    static func passwordToggleLabel(isVisible: Bool) -> String {
        isVisible ? "Hide password" : "Show password"
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
            secureTextContentType: .password,
            text: $password,
            didAttemptSubmit: true
        )
    }
    .padding()
}
