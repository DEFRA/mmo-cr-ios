import SwiftUI

/// Screen 3 of "Create a catch record": did your trip start and finish today?
struct TripStartedTodayView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: TripStartedTodayViewModel

    init(vessel: String, referenceNumber: String, router: CatchRecordRouter, favouritePorts: FavouritePortsProviding) {
        _viewModel = State(wrappedValue: TripStartedTodayViewModel(vessel: vessel, referenceNumber: referenceNumber, router: router, favouritePorts: favouritePorts))
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
                .accessibilityIdentifier("CatchRecord.tripToday.referenceNumber")

            TitleText(text: languageStore.localized("catchRecord.tripToday.heading"))
                .accessibilityAddTraits(.isHeader)

            ParagraphText(text: languageStore.localized("catchRecord.tripToday.hint.yes"), isHint: true)
            ParagraphText(text: languageStore.localized("catchRecord.tripToday.hint.no"), isHint: true)

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

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("CatchRecord.tripToday.saveContinue")
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selection?.id },
            set: { viewModel.selection = $0.flatMap(TripTodayOption.init(rawValue:)) }
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
