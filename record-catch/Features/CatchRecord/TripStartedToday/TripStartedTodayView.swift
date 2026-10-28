import SwiftUI

/// Screen 3 of "Create a catch record": did your trip start and finish today?
struct TripStartedTodayView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: TripStartedTodayViewModel

    init(
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding,
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: TripStartedTodayViewModel(
            vessel: vessel, referenceNumber: referenceNumber, router: router, favouritePorts: favouritePorts, draft: draft
        ))
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
            Text(viewModel.referenceNumber)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityIdentifier("CatchRecord.tripToday.referenceNumber")

            TitleText(text: languageStore.localized("catchRecord.tripToday.heading"))
                .accessibilityAddTraits(.isHeader)

            RadioGroup(
                options: [
                    RadioGroupOption(
                        id: TripTodayOption.yes.id,
                        title: languageStore.localized("catchRecord.tripToday.option.yes"),
                        accessibilityIdentifier: "CatchRecord.tripToday.option.yes"
                    ),
                    RadioGroupOption(
                        id: TripTodayOption.no.id,
                        title: languageStore.localized("catchRecord.tripToday.option.no"),
                        accessibilityIdentifier: "CatchRecord.tripToday.option.no"
                    )
                ],
                selectedID: selectionBinding,
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "CatchRecord.tripToday.radioGroup",
                errorAccessibilityIdentifier: "CatchRecord.tripToday.error"
            )
        }
    }

    // No separate "Save and continue" button: answering Yes/No is a single, discrete tap (the
    // activating gesture itself), so submitting immediately on selection does not trip WCAG 2.2
    // SC 3.2.2 "On Input" — that guards against a context change triggered by merely changing a
    // setting's value without an explicit activation, which a tap on a specific radio option
    // already is.
    private var selectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selection?.id },
            set: { newValue in
                viewModel.selection = newValue.flatMap(TripTodayOption.init(rawValue:))
                viewModel.submit()
            }
        )
    }
}

#Preview("English") {
    TripStartedTodayView(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    TripStartedTodayView(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    TripStartedTodayView(vessel: "ACHILLES", referenceNumber: "A1234520260727150815", router: CatchRecordRouter(), favouritePorts: StubFavouritePortsProvider())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
