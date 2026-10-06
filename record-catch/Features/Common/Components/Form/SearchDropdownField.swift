import SwiftUI

struct SearchDropdownField: View {
    let label: String
    let placeholder: String
    let minimumCharacters: Int
    let options: [String]
    @Binding var query: String
    @Binding var selectedOption: String?
    var didAttemptSubmit: Bool = false
    /// Number of "Save and continue" attempts. A monotonic counter, separate from
    /// `didAttemptSubmit`, so the error can be re-announced to VoiceOver on every attempt — the
    /// `false → true` edge of a `Bool` fires only once, leaving a VoiceOver user with silence on a
    /// second blank submit even though the visual error is still showing. Defaults to `0` so call
    /// sites that don't track attempts (none currently) keep working unchanged.
    var submitAttempt: Int = 0
    /// Error message shown when the query has no valid selection from the list. No default: every
    /// call site must supply its own localised, context-specific copy (see the GOV.UK guidance on
    /// specific error messages) rather than silently falling back to un-localised English port copy.
    var errorMessage: String
    /// Visually-hidden prefix spoken before the error message, mirroring GOV.UK's
    /// `govuk-visually-hidden` "Error:" prefix so VoiceOver announces "Error: <message>" exactly as
    /// every other error row in this app does. Defaults to English rather than reading
    /// `AppLanguageStore` from the environment because this file is also compiled into the
    /// `record-catchTests` target (see the note on the inline error row below); call sites pass
    /// `languageStore.localized("a11y.errorPrefix")`.
    var errorPrefix: String = "Error:"
    /// Whether the field announces its own error to assistive technology when it first appears, and
    /// again on every subsequent submit attempt (WCAG 2.2 SC 4.1.3 Status Messages). Set `false` on
    /// screens that already render an `ErrorSummary` — that component moves VoiceOver focus itself,
    /// and two simultaneous announcements talk over each other.
    var announcesError: Bool = true
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
        submitAttempt: Int = 0,
        errorMessage: String,
        errorPrefix: String = "Error:",
        announcesError: Bool = true,
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
        self.submitAttempt = submitAttempt
        self.errorMessage = errorMessage
        self.errorPrefix = errorPrefix
        self.announcesError = announcesError
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
        Self.shouldShowError(
            didAttemptSubmit: didAttemptSubmit,
            hasBlurred: hasBlurred,
            query: query,
            hasValidSelection: hasValidSelection
        )
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
                // GOV.UK's visually-hidden "Error:" prefix, so VoiceOver reads
                // "Error: Enter the port you want to add" — matching every other error in the app.
                .accessibilityLabel("\(errorPrefix) \(errorMessage)")
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
        // Announce the error on every submit attempt (not just the first) so a VoiceOver user who
        // presses "Save and continue" a second time while still blank is told again, rather than
        // meeting silence on an apparently unchanged screen (WCAG 2.2 SC 4.1.3 Status Messages).
        // Suppressed on screens that render an `ErrorSummary`, which moves focus itself — see
        // `announcesError`.
        .onChange(of: submitAttempt) { _, _ in
            guard shouldShowError, announcesError else { return }
            Self.announce("\(errorPrefix) \(errorMessage)")
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

    /// Whether the inline validation error should be shown.
    ///
    /// Two triggers, deliberately gated differently:
    ///
    /// - **Submit** (`didAttemptSubmit`) always errors when there is no valid selection, *including
    ///   when the field was left blank*. Omitting required information is an input error under
    ///   WCAG 2.2 SC 3.3.1, and GOV.UK requires an error message whenever a validation error
    ///   occurs — re-displaying an unchanged screen is a conformance failure.
    /// - **Blur** (`hasBlurred`) only errors a field the user actually typed into but did not pick
    ///   from the list. Merely focusing and leaving an untouched empty field must not accuse the
    ///   user of an error they have not yet had the chance to make.
    ///
    /// Pure and static so the gating is unit-testable without a hosted view, mirroring
    /// `TextInputField.shouldShowRequiredError`.
    static func shouldShowError(
        didAttemptSubmit: Bool,
        hasBlurred: Bool,
        query: String,
        hasValidSelection: Bool
    ) -> Bool {
        guard !hasValidSelection else { return false }
        if didAttemptSubmit { return true }
        return hasBlurred && !query.isEmpty
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
