import SwiftUI

struct SearchDropdownField: View {
    let label: String
    let placeholder: String
    let minimumCharacters: Int
    let options: [String]
    @Binding var query: String
    @Binding var selectedOption: String?
    var didAttemptSubmit: Bool = false
    /// Error message shown when the query has no valid selection from the list. No default: every
    /// call site must supply its own localised, context-specific copy (see the GOV.UK guidance on
    /// specific error messages) rather than silently falling back to un-localised English port copy.
    var errorMessage: String
    /// Localised "results" announcement builder for VoiceOver (WCAG 2.2 SC 4.1.3). Given a count,
    /// returns the phrase to announce (e.g. "5 results" / "No results"). Announcements are made
    /// without moving focus so the user is informed of changes to the results list.
    var resultsAnnouncement: (Int) -> String = { count in
        count == 0 ? "No results" : "\(count) results"
    }

    /// Caps how many results are visible at once before the list scrolls, rather than growing to
    /// fit every match and pushing the rest of the screen (e.g. the "Save and continue" button)
    /// out of view. Matching results beyond this count remain reachable by scrolling — none are
    /// discarded — so this only bounds on-screen height, not the result set itself.
    private static let maxVisibleResults = 6

    @FocusState private var isFocused: Bool
    @State private var hasBlurred = false
    @State private var lastAnnouncedCount: Int?
    /// Unique per-instance anchor so `ScrollViewProxy.scrollTo` targets this field's own results
    /// list rather than another `SearchDropdownField` on the same screen.
    private let resultsAnchorID = UUID()
    /// Optional accessibility identifier for the inline error, so UI tests can target it directly
    /// rather than matching on label text (which can collide with the field's own typed value).
    var errorAccessibilityIdentifier: String?

    @Environment(\.scrollViewProxy) private var scrollViewProxy

    init(
        label: String,
        placeholder: String = "Type to search",
        minimumCharacters: Int = 2,
        options: [String],
        query: Binding<String>,
        selectedOption: Binding<String?>,
        didAttemptSubmit: Bool = false,
        errorMessage: String,
        errorAccessibilityIdentifier: String? = nil,
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
        self.errorAccessibilityIdentifier = errorAccessibilityIdentifier
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
                .foregroundStyle(AppColors.textPrimary)
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
                // A plain `ScrollView` (rather than `List`/`ScrollViewReader` on the row content)
                // keeps every match reachable while capping the visible height to roughly
                // `maxVisibleResults` rows, so a large result set can never push the rest of the
                // screen (e.g. the "Save and continue" button) out of view. VoiceOver/Voice
                // Control users can still reach every row by scrolling; nothing is discarded, only
                // the on-screen height is bounded.
                ScrollView(.vertical) {
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
                            .frame(minHeight: AppControlSize.minTapTarget)
                            // An explicit, stable identifier for UI tests to target, independent of
                            // the option's own label text: a plain `VStack`/`Button` combination
                            // doesn't otherwise reliably expose a container-level identifier to
                            // XCUITest, and matching by label text alone can collide with the
                            // `TextField` above once its typed value equals the same text.
                            .accessibilityIdentifier(Self.resultIdentifier(for: option))

                            Divider()
                        }
                    }
                }
                .frame(maxHeight: AppControlSize.minTapTarget * CGFloat(Self.maxVisibleResults))
                .overlay(
                    Rectangle()
                        .stroke(AppColors.borderDefault, lineWidth: 1)
                )
                .id(resultsAnchorID)
            }

            if shouldShowError {
                // Inlined (rather than delegating to the shared `InlineErrorText`) because this
                // file is also compiled directly into the `record-catchTests` target (alongside
                // several other `Common/Components` files), which does not include every file in
                // `Common` — keeping this self-contained avoids an unresolved-symbol build error
                // there. `AccessibilityAnnouncer`'s helper is duplicated below for the same reason.
                HStack(alignment: .top, spacing: AppSpacing.xSmall) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(AppColors.errorRed)
                        .accessibilityHidden(true)
                    Text(errorMessage)
                        .font(AppTypography.error)
                        .foregroundStyle(AppColors.errorRed)
                }
                .accessibilityElement(children: .combine)
                .modifier(SearchDropdownFieldErrorIdentifier(identifier: errorAccessibilityIdentifier))
            }
        }
        // The results list renders below the field as ordinary sibling content, so SwiftUI's
        // built-in keyboard-avoidance (which only guarantees the *focused* control stays
        // visible) can leave it hidden behind the keyboard. Once results appear, explicitly
        // scroll the enclosing `ScrollView` (via the proxy `ViewTemplate` publishes) so the
        // list is brought above the keyboard. Deferred to the next run loop pass so the results
        // view has been laid out and has a frame to scroll to.
        .onChange(of: showResults) { _, isShowing in
            guard isShowing else { return }
            scrollResultsIntoView()
        }
        // Also keep the results in view as the list changes size while the user keeps typing.
        .onChange(of: filteredOptions.count) { _, _ in
            guard showResults else { return }
            scrollResultsIntoView()
        }
    }

    private func scrollResultsIntoView() {
        DispatchQueue.main.async {
            withAnimation {
                scrollViewProxy?.scrollTo(resultsAnchorID, anchor: .bottom)
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
    /// `UIAccessibility` notification on iOS 16 (the app's minimum deployment target). Duplicated
    /// from `AccessibilityAnnouncer` rather than delegating to it — see the comment on the inline
    /// error row above for why this file stays self-contained.
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

    /// Stable, unambiguous accessibility identifier for a results-list row, keyed by the option's
    /// own text. UI tests should target this rather than the option's label text directly (see the
    /// identifier modifier above for why).
    static func resultIdentifier(for option: String) -> String {
        "SearchDropdownField.result.\(option)"
    }
}

/// Applies `.accessibilityIdentifier` only when one is supplied — duplicated from
/// `InlineErrorText`'s equivalent modifier for the same dual-target reason (see above).
private struct SearchDropdownFieldErrorIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
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
        didAttemptSubmit: true,
        errorMessage: "Select a port from the list"
    )
    .padding()
}
