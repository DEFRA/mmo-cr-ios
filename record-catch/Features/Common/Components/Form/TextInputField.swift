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
        // An externally-supplied error (e.g. a per-species weight validation message) always wins
        // once a submit has been attempted, regardless of the field's own blank/required check —
        // this lets a caller validate format/range rules on an otherwise-optional field.
        if didAttemptSubmit, errorMessage != nil {
            return true
        }
        return Self.shouldShowRequiredError(
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
                // Inlined (rather than delegating to the shared `InlineErrorText`) because this
                // file is also compiled directly into the `record-catchTests` target, which does
                // not include every file in `Common` — keeping this self-contained avoids an
                // unresolved-symbol build error there (see `SearchDropdownField`'s equivalent note).
                HStack(alignment: .top, spacing: AppSpacing.xSmall) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(AppColors.errorRed)
                        .accessibilityHidden(true)
                    Text(resolvedErrorMessage)
                        .font(AppTypography.error)
                        .foregroundStyle(AppColors.errorRed)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                hasBlurred = true
            }
        }
        .onChange(of: text) { _, newValue in
            // Live-sanitise decimal-pad input: the on-screen numeric keypad happily lets a user
            // tap "." repeatedly (e.g. "......888"), which upstream weight/precision validation
            // only catches once "Save and continue" is pressed. Filtering as the user types keeps
            // the field always in a valid numeric shape rather than surfacing an error later —
            // GOV.UK's "prevent errors" pattern (https://www.gov.uk/service-manual/design/prevent-user-errors).
            guard keyboardType == .decimalPad else { return }
            let sanitized = Self.sanitizedDecimalInput(newValue)
            if sanitized != newValue {
                text = sanitized
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

    /// Filters `raw` down to a shape a decimal number can always be typed into: digits and **at
    /// most one** "." decimal point. Any additional "." (e.g. from repeatedly tapping the
    /// decimal-pad's dot key, as in "......888" or "11......2222") is dropped rather than
    /// accepted, and any other stray character is dropped too. Pure and static so the
    /// keystroke-level filtering is unit-testable without a hosted view.
    ///
    /// This only prevents an invalid *shape* (multiple decimal points / non-numeric characters)
    /// as the user types; it deliberately does not enforce a specific number of decimal places or
    /// a value range — those remain the job of the per-field validation run on submit (e.g.
    /// `SpeciesWeightValidation`, which knows the field's required `WeightPrecision`).
    static func sanitizedDecimalInput(_ raw: String) -> String {
        var result = ""
        var hasDecimalPoint = false
        for character in raw {
            if character.isASCII, character.isNumber {
                result.append(character)
            } else if character == ".", !hasDecimalPoint {
                result.append(character)
                hasDecimalPoint = true
            }
        }
        return result
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
