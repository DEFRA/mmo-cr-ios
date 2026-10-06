import SwiftUI

/// A native date-picker field for the trip-date screens (departure and return).
///
/// Deliberately deviates from the GOV.UK Design System's day/month/year *Date input* pattern in
/// favour of SwiftUI's native `DatePicker` — see ADR-0017 for the justification and the recorded
/// deviation. Because the caller (`TripDateViewModel`) always supplies a concrete `selection` and
/// a `range` that clamps out every impossible value, this view has no validation or error-state
/// logic of its own — unlike the `DateEntryField` it replaces, there is no "missing"/"not a real
/// date" state to render.
///
/// - Important: Uses `.datePickerStyle(.wheel)` to present separate day/month/year wheels. This
///   **supersedes ADR-0017 decision #2**, which originally chose `.compact` and explicitly
///   rejected `.wheel` over Dynamic Type reflow and VoiceOver concerns — that rejection has not
///   yet been re-verified against this style. ADR-0017 must be updated (or a follow-up ADR
///   raised) and a manual accessibility pass (Dynamic Type to 200%, VoiceOver adjustable-value
///   announcement, 44×44pt row targets) completed before this ships to production.
///
/// - Important: When `range` collapses to a single selectable day (e.g. the trip return date
///   screen when the departure date is today, so the only legal return date is also today), this
///   view deliberately does **not** render the interactive `.wheel` `DatePicker`. A
///   `UIPickerView`-backed wheel with zero scrollable rows in one or more of its columns is a
///   known-unstable UIKit configuration: it repeatedly fails to satisfy its own internal layout
///   constraints (visible as `TUIKeyplaneView`/`TUIPredictionViewCell` "Unable to simultaneously
///   satisfy constraints" log spam) and can hang/crash on-device the moment a user touches it —
///   this is what the crash reported against the return-date screen turned out to be. Since there
///   is only one legal value in that case, nothing is lost by presenting it as a static, accessible
///   confirmation instead of a picker with nothing to scroll to.
struct TripDatePicker: View {
    let title: String
    let hint: String
    @Binding var selection: Date
    let range: ClosedRange<Date>
    /// Localised format string (one `%@` placeholder for the formatted date) shown instead of the
    /// wheel picker when `range` collapses to a single selectable day. Resolved by the caller via
    /// `AppLanguageStore` (catalog key `catchRecord.tripDate.onlyDateAvailable`) so this reusable
    /// component does not need its own localisation dependency.
    let onlyDateAvailableFormat: String
    /// Locale used only to format the single-day fallback's date text (e.g. "24 July 2025" vs the
    /// Welsh equivalent). Passed explicitly by the caller rather than read from the environment so
    /// this stays in step with `AppLanguageStore.language`, which does not change the environment
    /// locale consumed by `DateFormatter.locale` automatically.
    var dateFormattingLocale: Locale = .current
    /// Accessibility identifier prefix; the picker control uses `<prefix>.picker` (or
    /// `<prefix>.onlyDateAvailable` for the single-day fallback below).
    var accessibilityIdentifierPrefix: String = "TripDatePicker"

    /// `range` collapses to a single legal day — there is nothing to pick between, so an
    /// interactive wheel must not be rendered (see the type-level doc comment above).
    private var hasOnlySelectableDay: Bool { range.lowerBound == range.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ParagraphText(text: hint, isHint: true)

            if hasOnlySelectableDay {
                onlyDateAvailable
            } else {
                DatePicker(
                    title,
                    selection: $selection,
                    in: range,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel(title)
                .accessibilityIdentifier("\(accessibilityIdentifierPrefix).picker")
            }
        }
        .onAppear {
            // Defensive: guarantees `selection` reflects the single legal value even if a stale
            // caller ever supplied something else, so there is nothing left to validate.
            if hasOnlySelectableDay, selection != range.lowerBound {
                selection = range.lowerBound
            }
        }
    }

    private var onlyDateAvailable: some View {
        let dateText = CatchRecordDateRules.longDateString(range.lowerBound, locale: dateFormattingLocale)
        let message = String(format: onlyDateAvailableFormat, dateText)
        return ParagraphText(text: message)
            .padding(.vertical, AppSpacing.small)
            .accessibilityIdentifier("\(accessibilityIdentifierPrefix).onlyDateAvailable")
    }
}

#Preview {
    @Previewable @State var date = Date()

    return TripDatePicker(
        title: "When did you leave for your trip?",
        hint: "Select the date you left for your trip.",
        selection: $date,
        range: Date.distantPast...Date(),
        onlyDateAvailableFormat: "The only date you can select is %@.",
        accessibilityIdentifierPrefix: "Preview.tripDate"
    )
    .padding()
}

#Preview("Only one selectable day") {
    @Previewable @State var date = Date()

    return TripDatePicker(
        title: "When did you return from your trip?",
        hint: "Select the date you returned from your trip.",
        selection: $date,
        range: Date()...Date(),
        onlyDateAvailableFormat: "The only date you can select is %@.",
        accessibilityIdentifierPrefix: "Preview.tripDate.onlyDay"
    )
    .padding()
}
