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
///   view still renders a scrolling **wheel** control — see `singleDayWheel` — rather than
///   switching to a different picker style or a static-text fallback. See ADR-0017 addendum
///   (2026-11-03) for why this is safe: it deliberately does **not** reuse `DatePicker`'s compound
///   day/month/year `.wheel` machinery, which is what previously crashed here (a `UIDatePicker`
///   wheel with zero scrollable rows in one or more of its columns is a known-unstable UIKit
///   configuration — see the 2026-10-12 addendum). Instead it is a plain SwiftUI `Picker` with a
///   single row bound to the one valid date; that is an ordinary, stable wheel-picker
///   configuration used throughout iOS (a `UIPickerView` with one row in one column), so it never
///   reaches the failure mode that the compound `DatePicker` wheel did.
struct TripDatePicker: View {
    let title: String
    @Binding var selection: Date
    let range: ClosedRange<Date>
    /// Accessibility identifier prefix; the picker control uses `<prefix>.picker` regardless of
    /// which style is rendered.
    var accessibilityIdentifierPrefix: String = "TripDatePicker"

    @Environment(\.locale) private var locale

    /// `range` collapses to a single legal day — there is nothing to scroll between, so the
    /// `DatePicker`-backed `.wheel` configuration must not be rendered (see the type-level doc
    /// comment above). `singleDayWheel` is used instead.
    private var hasOnlySelectableDay: Bool { range.lowerBound == range.upperBound }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            if hasOnlySelectableDay {
                singleDayWheel
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

    /// A genuine scrolling wheel with exactly one, already-selected row — matches the multi-day
    /// case's wheel appearance without reusing `DatePicker`'s crash-prone compound wheel (see the
    /// type-level doc comment). There is nothing else to scroll to, so the control is effectively
    /// locked to `range.lowerBound`, but it is never rendered as a tappable button/capsule.
    private var singleDayWheel: some View {
        Picker(title, selection: $selection) {
            Text(CatchRecordDateRules.longDateString(range.lowerBound, locale: locale))
                .tag(range.lowerBound)
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityLabel(title)
        .accessibilityValue(CatchRecordDateRules.longDateString(range.lowerBound, locale: locale))
        .accessibilityIdentifier("\(accessibilityIdentifierPrefix).picker")
    }
}

#Preview {
    @Previewable @State var date = Date()

    return TripDatePicker(
        title: "When did you leave for your trip?",
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
        selection: $date,
        range: Date()...Date(),
        accessibilityIdentifierPrefix: "Preview.tripDate.onlyDay"
    )
    .padding()
}
