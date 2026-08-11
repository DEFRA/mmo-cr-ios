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

            DateEntryField(
                title: languageStore.localized(viewModel.titleKey),
                hint: languageStore.localized(viewModel.hintKey),
                value: Binding(
                    get: { viewModel.value },
                    set: { viewModel.value = $0 }
                ),
                didAttemptSubmit: viewModel.didAttemptSubmit,
                errorKey: viewModel.errorKey ?? "catchRecord.tripDate.validation.none",
                accessibilityIdentifierPrefix: identifierPrefix
            )

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
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
