import SwiftUI

/// Screen 2 of "Create a catch record": select the vessel for this trip.
struct SelectVesselView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SelectVesselViewModel

    init(
        router: CatchRecordRouter,
        provider: VesselProviding = SyncedVesselSearchProvider(),
        draft: CatchRecordDraft = CatchRecordDraft()
    ) {
        _viewModel = State(wrappedValue: SelectVesselViewModel(router: router, provider: provider, draft: draft))
    }

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            TitleText(text: languageStore.localized("catchRecord.selectVessel.heading"))
                .accessibilityAddTraits(.isHeader)

            switch viewModel.state {
            case .loading:
                loadingState
            case .empty:
                emptyState
            case .loaded(let vessels):
                vesselOptions(vessels)
            }
        }
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.large)
            .accessibilityIdentifier("CatchRecord.selectVessel.loading")
            .accessibilityLabel(languageStore.localized("catchRecord.selectVessel.loading"))
    }

    private func vesselOptions(_ vessels: [VesselOption]) -> some View {
        RadioGroup(
            options: vessels.map { vessel in
                RadioGroupOption(
                    id: vessel.id,
                    title: vessel.displayName,
                    accessibilityIdentifier: "CatchRecord.selectVessel.option.\(Self.identifierSuffix(for: vessel))"
                )
            },
            // No separate "Save and continue" button: choosing a vessel is a single, discrete
            // tap (the activating gesture itself), so submitting immediately on selection does
            // not trip WCAG 2.2 SC 3.2.2 "On Input" — that guards against a context change
            // triggered by merely changing a setting's value without an explicit activation,
            // which a tap on a specific radio option already is.
            selectedID: Binding(
                get: { viewModel.selectionID },
                set: { newValue in
                    viewModel.selectionID = newValue
                    viewModel.submit()
                }
            ),
            errorKey: viewModel.errorKey,
            groupAccessibilityIdentifier: "CatchRecord.selectVessel.radioGroup",
            errorAccessibilityIdentifier: "CatchRecord.selectVessel.error"
        )
    }

    /// Shown when the signed-in user has no vessels available to select — never an indefinite
    /// spinner, perceivable by text and icon (never colour alone), and announced via the same
    /// error styling used elsewhere (e.g. `DataPreparationView`'s failure summary).
    private var emptyState: some View {
        HStack(alignment: .top, spacing: AppSpacing.xSmall) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(AppColors.errorRed)
                .accessibilityHidden(true)
            LocalizedText("catchRecord.selectVessel.empty.message")
                .font(AppTypography.error)
                .foregroundStyle(AppColors.errorRed)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(AppColors.errorRed, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized("catchRecord.selectVessel.empty.message"))")
        .accessibilityIdentifier("CatchRecord.selectVessel.empty")
    }

    /// Builds a stable, lower-case, hyphenated accessibility-identifier suffix from a vessel's
    /// name (e.g. `"SEA SPRAY"` → `"sea-spray"`) — mirrors the identifier scheme already used by
    /// UI tests for the previous static two-vessel list.
    private static func identifierSuffix(for vessel: VesselOption) -> String {
        vessel.name.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

#Preview("English") {
    SelectVesselView(router: CatchRecordRouter(), provider: StubVesselProvider())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    SelectVesselView(router: CatchRecordRouter(), provider: StubVesselProvider())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    SelectVesselView(router: CatchRecordRouter(), provider: StubVesselProvider())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("No vessels") {
    SelectVesselView(router: CatchRecordRouter(), provider: StubVesselProvider(vessels: []))
        .environment(AppLanguageStore.preview)
}
