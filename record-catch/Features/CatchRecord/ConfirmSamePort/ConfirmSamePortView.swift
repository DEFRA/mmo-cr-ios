import SwiftUI

/// "Was `<port>` your departure and return port?" — reached after saving a searched port on
/// `AddPortView`'s first-time entry (no favourites yet). "Yes" bypasses the separate
/// departure/return select screens; "No" continues into them as before. Mirrors the
/// `LandingStorageView`/`SelectPortView` Yes/No + "Add another port" pattern.
struct ConfirmSamePortView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: ConfirmSamePortViewModel

    init(
        vessel: String,
        referenceNumber: String,
        port: PortOption,
        router: CatchRecordRouter,
        favouriteGears: FavouriteGearProviding,
        draft: CatchRecordDraft
    ) {
        _viewModel = State(wrappedValue: ConfirmSamePortViewModel(
            vessel: vessel,
            referenceNumber: referenceNumber,
            port: port,
            router: router,
            favouriteGears: favouriteGears,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.confirmSamePort"

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

            TitleText(text: heading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            ParagraphText(text: languageStore.localized("catchRecord.confirmSamePort.hint"), isHint: true)

            RadioGroup(
                options: [
                    RadioGroupOption(
                        id: ConfirmSamePortOption.yes.id,
                        title: languageStore.localized("catchRecord.confirmSamePort.option.yes"),
                        accessibilityIdentifier: "\(identifierPrefix).option.yes"
                    ),
                    RadioGroupOption(
                        id: ConfirmSamePortOption.no.id,
                        title: languageStore.localized("catchRecord.confirmSamePort.option.no"),
                        accessibilityIdentifier: "\(identifierPrefix).option.no"
                    )
                ],
                selectedID: selectionBinding,
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

    private var heading: String {
        String(
            format: languageStore.localized("catchRecord.confirmSamePort.heading"),
            viewModel.port.name
        )
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selection?.id },
            set: { viewModel.selection = $0.flatMap(ConfirmSamePortOption.init(rawValue:)) }
        )
    }
}

#Preview("English") {
    ConfirmSamePortView(
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        port: PortOption(name: "Hastings"),
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider(),
        draft: CatchRecordDraft()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    ConfirmSamePortView(
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        port: PortOption(name: "Hastings"),
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider(),
        draft: CatchRecordDraft()
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    ConfirmSamePortView(
        vessel: "ACHILLES",
        referenceNumber: "A1234520260727150815",
        port: PortOption(name: "Hastings"),
        router: CatchRecordRouter(),
        favouriteGears: StubFavouriteGearProvider(),
        draft: CatchRecordDraft()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
