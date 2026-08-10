import SwiftUI

/// Reusable "Which port did you leave from / return to?" screen.
///
/// Serves both the departure and return variants of the design, driven by `SelectPortPhase`
/// (mirroring `TripDateView`). Shows the user's favourite ports as a radio group with "Save and
/// continue" and a secondary "Add another port" button.
struct SelectPortView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: SelectPortViewModel

    init(
        phase: SelectPortPhase,
        vessel: String,
        referenceNumber: String,
        router: CatchRecordRouter,
        favouritePorts: FavouritePortsProviding
    ) {
        _viewModel = State(wrappedValue: SelectPortViewModel(
            phase: phase,
            vessel: vessel,
            referenceNumber: referenceNumber,
            router: router,
            favouritePorts: favouritePorts
        ))
    }

    private var identifierPrefix: String {
        "CatchRecord.selectPort.\(viewModel.phase.accessibilityIdentifierFragment)"
    }

    var body: some View {
        ViewTemplate(title: "") {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.loadFavourites() }
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

            TitleText(text: languageStore.localized(viewModel.phase.titleKey))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            ParagraphText(text: languageStore.localized(viewModel.phase.hintKey))

            RadioGroup(
                options: viewModel.favourites.map { port in
                    RadioGroupOption(
                        id: port.name,
                        title: port.name,
                        accessibilityIdentifier: "\(identifierPrefix).option.\(port.name.lowercased())"
                    )
                },
                selectedID: Binding(get: { viewModel.selection }, set: { viewModel.selection = $0 }),
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "\(identifierPrefix).radioGroup",
                errorAccessibilityIdentifier: "\(identifierPrefix).error"
            )

            VStack(spacing: AppSpacing.small) {
                PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                    viewModel.submit()
                }
                .accessibilityIdentifier("\(identifierPrefix).saveContinue")

                SecondaryButton(title: languageStore.localized("catchRecord.addAnotherPort")) {
                    viewModel.addAnotherPort()
                }
                .accessibilityIdentifier("\(identifierPrefix).addAnother")
            }
        }
    }
}

#Preview("Departure — English") {
    SelectPortView(
        phase: .departure,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Return — Welsh") {
    SelectPortView(
        phase: .return,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    SelectPortView(
        phase: .departure,
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        favouritePorts: StubFavouritePortsProvider(initialFavourites: [PortOption(name: "Hastings")])
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
