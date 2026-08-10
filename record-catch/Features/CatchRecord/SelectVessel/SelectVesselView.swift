import SwiftUI

/// Screen 2 of "Create a catch record": select the vessel for this trip.
struct SelectVesselView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SelectVesselViewModel

    init(router: CatchRecordRouter, provider: VesselProviding = StaticVesselProvider()) {
        _viewModel = State(wrappedValue: SelectVesselViewModel(router: router, provider: provider))
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

            TitleText(text: languageStore.localized("catchRecord.selectVessel.heading"))
                .accessibilityAddTraits(.isHeader)

            RadioGroup(
                options: viewModel.vessels.map { vessel in
                    RadioGroupOption(
                        id: vessel,
                        title: vessel,
                        accessibilityIdentifier: "CatchRecord.selectVessel.option.\(vessel.lowercased())"
                    )
                },
                selectedID: Binding(
                    get: { viewModel.selection },
                    set: { viewModel.selection = $0 }
                ),
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "CatchRecord.selectVessel.radioGroup",
                errorAccessibilityIdentifier: "CatchRecord.selectVessel.error"
            )

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("CatchRecord.selectVessel.saveContinue")
        }
    }
}

#Preview("English") {
    SelectVesselView(router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SelectVesselView(router: CatchRecordRouter())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    SelectVesselView(router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
