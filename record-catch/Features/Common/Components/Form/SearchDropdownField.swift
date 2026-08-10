import SwiftUI

struct SearchDropdownField: View {
    let label: String
    let placeholder: String
    let minimumCharacters: Int
    let options: [String]
    @Binding var query: String
    @Binding var selectedOption: String?
    var didAttemptSubmit: Bool = false
    /// Error message shown when the query has no valid selection from the list.
    var errorMessage: String = "Select a port from the list"
    /// Localised "results" announcement builder for VoiceOver (WCAG 2.2 SC 4.1.3). Given a count,
    /// returns the phrase to announce (e.g. "5 results" / "No results"). Announcements are made
    /// without moving focus so the user is informed of changes to the results list.
    var resultsAnnouncement: (Int) -> String = { count in
        count == 0 ? "No results" : "\(count) results"
    }

    @FocusState private var isFocused: Bool
    @State private var hasBlurred = false
    @State private var lastAnnouncedCount: Int?

    init(
        label: String,
        placeholder: String = "Type to search",
        minimumCharacters: Int = 2,
        options: [String],
        query: Binding<String>,
        selectedOption: Binding<String?>,
        didAttemptSubmit: Bool = false,
        errorMessage: String = "Select a port from the list",
        resultsAnnouncement: @escaping (Int) -> String = { $0 == 0 ? "No results" : "\($0) results" }
    ) {
        self.label = label
        self.placeholder = placeholder
        self.minimumCharacters = minimumCharacters
        self.options = options
        _query = query
        _selectedOption = selectedOption
        self.didAttemptSubmit = didAttemptSubmit
        self.errorMessage = errorMessage
        self.resultsAnnouncement = resultsAnnouncement
    }

    private var filteredOptions: [String] {
        Self.filteredOptions(
            query: query,
            minimumCharacters: minimumCharacters,
            options: options
        )
    }

    private var hasValidSelection: Bool {
        Self.hasValidSelection(
            selectedOption: selectedOption,
            query: query,
            options: options
        )
    }

    private var shouldShowError: Bool {
        (didAttemptSubmit || hasBlurred) && !query.isEmpty && !hasValidSelection
    }

    private var showResults: Bool {
        isFocused && !filteredOptions.isEmpty && selectedOption == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)

            TextField(placeholder + " (minimum \(minimumCharacters) characters)", text: $query)
                .font(AppTypography.bodySmall)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, AppSpacing.small)
                .frame(height: AppControlSize.dateFieldHeight)
                .overlay(
                    Rectangle()
                        .stroke(shouldShowError ? AppColors.errorRed : AppColors.borderStrong, lineWidth: 1)
                )
                .focused($isFocused)
                .onChange(of: query) { _, newValue in
                    if selectedOption != newValue {
                        selectedOption = nil
                    }
                    announceResultsIfNeeded()
                }
                .onChange(of: isFocused) { _, newValue in
                    if !newValue {
                        hasBlurred = true
                    }
                }

            if showResults {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredOptions, id: \.self) { option in
                        Button(option) {
                            selectedOption = option
                            query = option
                            isFocused = false
                        }
                        .buttonStyle(.plain)
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.small)

                        Divider()
                    }
                }
                .overlay(
                    Rectangle()
                        .stroke(AppColors.borderDefault, lineWidth: 1)
                )
            }

            if shouldShowError {
                Text(errorMessage)
                    .font(AppTypography.error)
                    .foregroundStyle(AppColors.errorRed)
            }
        }
    }

    /// Announces the current result count to assistive technology without moving focus, when it
    /// changes and the query is long enough to search (WCAG 2.2 SC 4.1.3 Status Messages).
    private func announceResultsIfNeeded() {
        guard query.count >= minimumCharacters, selectedOption == nil else {
            lastAnnouncedCount = nil
            return
        }
        let count = filteredOptions.count
        guard count != lastAnnouncedCount else { return }
        lastAnnouncedCount = count
        Self.announce(resultsAnnouncement(count))
    }

    /// Posts a VoiceOver announcement using the iOS 17+ API where available, falling back to the
    /// `UIAccessibility` notification on iOS 16 (the app's minimum deployment target).
    static func announce(_ message: String) {
        if #available(iOS 17, *) {
            var announcement = AttributedString(message)
            announcement.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(announcement).post()
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    static func filteredOptions(query: String, minimumCharacters: Int, options: [String]) -> [String] {
        guard query.count >= minimumCharacters else {
            return []
        }

        return options.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    static func hasValidSelection(selectedOption: String?, query: String, options: [String]) -> Bool {
        guard let selectedOption else {
            return false
        }

        return options.contains(selectedOption) && selectedOption == query
    }
}

#Preview {
    @Previewable @State var query = ""
    @Previewable @State var selected: String?

    return SearchDropdownField(
        label: "Add port to vessel ACHILLES",
        options: StubPortOptionProvider().options,
        query: $query,
        selectedOption: $selected,
        didAttemptSubmit: true
    )
    .padding()
}
