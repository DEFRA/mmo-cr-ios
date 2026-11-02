import SwiftUI

/// Screen 2 of "Create a catch record": select the vessel for this trip.
struct SelectVesselView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SelectVesselViewModel

    init(
        router: CatchRecordRouter,
        provider: VesselProviding = StaticVesselProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: SelectVesselViewModel(router: router, provider: provider, draft: draft))
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
                // No separate "Save and continue" button: choosing a vessel is a single, discrete
                // tap (the activating gesture itself), so submitting immediately on selection does
                // not trip WCAG 2.2 SC 3.2.2 "On Input" — that guards against a context change
                // triggered by merely changing a setting's value without an explicit activation,
                // which a tap on a specific radio option already is.
                selectedID: Binding(
                    get: { viewModel.selection },
                    set: { newValue in
                        viewModel.selection = newValue
                        viewModel.submit()
                    }
                ),
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "CatchRecord.selectVessel.radioGroup",
                errorAccessibilityIdentifier: "CatchRecord.selectVessel.error"
            )
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
