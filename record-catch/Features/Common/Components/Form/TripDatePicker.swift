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
///   view renders the **same** `DatePicker` with `.datePickerStyle(.compact)` instead of
///   `.wheel`. A `UIPickerView`-backed wheel with zero scrollable rows in one or more of its
///   columns is a known-unstable UIKit configuration: it repeatedly fails to satisfy its own
///   internal layout constraints (visible as `TUIKeyplaneView`/`TUIPredictionViewCell` "Unable to
///   simultaneously satisfy constraints" log spam) and can hang/crash on-device the moment a user
///   touches it — this is what the crash reported against the return-date screen turned out to
///   be. `.compact`'s popover calendar grid does not have that failure mode even with a single
///   enabled day, so switching style (rather than substituting a bespoke static-text state that
///   was never part of the approved design — see ADR-0017 addendum) keeps the screen crash-safe
///   while staying a plain native `DatePicker` throughout.
struct TripDatePicker: View {
    let title: String
    let hint: String
    @Binding var selection: Date
    let range: ClosedRange<Date>
    /// Accessibility identifier prefix; the picker control uses `<prefix>.picker` regardless of
    /// which style is rendered.
    var accessibilityIdentifierPrefix: String = "TripDatePicker"

    /// `range` collapses to a single legal day — there is nothing to scroll between, so the
    /// unstable `.wheel` configuration must not be rendered (see the type-level doc comment
    /// above). `.compact` is used instead; it remains a fully interactive native `DatePicker`.
    private var hasOnlySelectableDay: Bool { range.lowerBound == range.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ParagraphText(text: hint, isHint: true)

            if hasOnlySelectableDay {
                datePicker
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: nil, alignment: .leading)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("\(accessibilityIdentifierPrefix).picker")
            } else {
                datePicker
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

    private var datePicker: some View {
        DatePicker(
            title,
            selection: $selection,
            in: range,
            displayedComponents: .date
        )
    }
}

#Preview {
    @Previewable @State var date = Date()

    return TripDatePicker(
        title: "When did you leave for your trip?",
        hint: "Select the date you left for your trip.",
        selection: $date,
        range: Date.distantPast...Date(),
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
        accessibilityIdentifierPrefix: "Preview.tripDate.onlyDay"
    )
    .padding()
}
