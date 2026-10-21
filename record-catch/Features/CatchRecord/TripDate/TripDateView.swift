import SwiftUI

/// Reusable "trip date" screen for the "Create a catch record" journey.
///
/// Serves both the departure ("When did you leave for your trip?") and return
/// ("When did you return from your trip?") variants of the design, driven by
/// `TripDatePhase`. Reached from the "No" answer on the trip-started-today screen.
struct TripDateView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: TripDateViewModel

    init(
        phase: TripDatePhase,
        vessel: String,
        referenceNumber: String,
        departureDate: Date?,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding,
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: TripDateViewModel(
            phase: phase,
            vessel: vessel,
            referenceNumber: referenceNumber,
            departureDate: departureDate,
            router: router,
            favouritePorts: favouritePorts,
            draft: draft
        ))
    }

    private var identifierPrefix: String {
        "CatchRecord.tripDate.\(viewModel.phase.accessibilityIdentifierFragment)"
    }

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            LocalizedText("catchRecord.caption")
                .font(AppTypography.pageCaption)
                .foregroundStyle(AppColors.govBlue)

            Text(viewModel.referenceNumber)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityIdentifier("\(identifierPrefix).referenceNumber")

            TitleText(text: languageStore.localized(viewModel.titleKey))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            if viewModel.dateWasAdjustedForAgeLimit {
                adjustedDateNotice
            }

            TripDatePicker(
                title: languageStore.localized(viewModel.titleKey),
                hint: languageStore.localized(viewModel.hintKey),
                selection: Binding(
                    get: { viewModel.selectedDate },
                    set: { viewModel.selectedDate = $0 }
                ),
                range: viewModel.selectableRange,
                accessibilityIdentifierPrefix: identifierPrefix
            )

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
        }
    }

    /// Informational (non-blocking) notice shown when a resumed draft's departure date has been
    /// moved forward because it is now more than 365 days in the past (BR-CAT-006/AC02). Announced
    /// once on appear so VoiceOver users are told about the change without it stealing focus
    /// (WCAG 2.2 SC 4.1.3 Status Messages).
    private var adjustedDateNotice: some View {
        WarningBox(
            tagKey: "catchRecord.tripDate.adjustedForAgeLimit.tag",
            messageKey: "catchRecord.tripDate.adjustedForAgeLimit.message"
        )
        .accessibilityIdentifier("\(identifierPrefix).adjustedForAgeLimitNotice")
        .task {
            let message = WarningBox.accessibilityLabel(
                tag: languageStore.localized("catchRecord.tripDate.adjustedForAgeLimit.tag"),
                message: languageStore.localized("catchRecord.tripDate.adjustedForAgeLimit.message")
            )
            AccessibilityAnnouncer.announce(message)
        }
    }
}

#Preview("Departure — English") {
    TripDateView(phase: .departure, vessel: "ACHILLES", referenceNumber: "A1234520260727150815", departureDate: nil, router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
}

#Preview("Return — English") {
    TripDateView(phase: .return, vessel: "ACHILLES", referenceNumber: "A1234520260727150815", departureDate: nil, router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
}

#Preview("Departure — Welsh") {
    TripDateView(phase: .departure, vessel: "ACHILLES", referenceNumber: "A1234520260727150815", departureDate: nil, router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    TripDateView(phase: .departure, vessel: "ACHILLES", referenceNumber: "A1234520260727150815", departureDate: nil, router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
