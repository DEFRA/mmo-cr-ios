import SwiftUI

/// A native date-picker field for the trip-date screens (departure and return).
///
/// Deliberately deviates from the GOV.UK Design System's day/month/year *Date input* pattern in
/// favour of SwiftUI's native `DatePicker` — see ADR-0017 for the justification and the recorded
/// deviation. Because the caller (`TripDateViewModel`) always supplies a concrete `selection` and
/// a `range` that clamps out every impossible value, this view has no validation or error-state
/// logic of its own — unlike the `DateEntryField` it replaces, there is no "missing"/"not a real
/// date" state to render.
struct TripDatePicker: View {
    let title: String
    let hint: String
    @Binding var selection: Date
    let range: ClosedRange<Date>
    /// Accessibility identifier prefix; the picker control uses `<prefix>.picker`.
    var accessibilityIdentifierPrefix: String = "TripDatePicker"

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ParagraphText(text: hint, isHint: true)

            DatePicker(
                title,
                selection: $selection,
                in: range,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(minHeight: AppControlSize.dateFieldHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(title)
            .accessibilityIdentifier("\(accessibilityIdentifierPrefix).picker")
        }
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
