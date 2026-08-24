import SwiftUI

/// "Is there any catch from this trip that you will not be landing straight away?" — a Yes/No
/// question reached after the species weights screen. Mirrors the trip-started-today radio screen.
struct LandingStorageView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: LandingStorageViewModel

    init(referenceNumber: String, router: CatchRecordRouter) {
        _viewModel = State(wrappedValue: LandingStorageViewModel(referenceNumber: referenceNumber, router: router))
    }

    private let identifierPrefix = "CatchRecord.landingStorage"

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

            TitleText(text: languageStore.localized("catchRecord.landingStorage.heading"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            ParagraphText(text: languageStore.localized("catchRecord.landingStorage.hint"), isHint: true)

            RadioGroup(
                options: [
                    RadioGroupOption(
                        id: LandingStorageOption.yes.id,
                        title: languageStore.localized("catchRecord.landingStorage.option.yes"),
                        accessibilityIdentifier: "\(identifierPrefix).option.yes"
                    ),
                    RadioGroupOption(
                        id: LandingStorageOption.no.id,
                        title: languageStore.localized("catchRecord.landingStorage.option.no"),
                        accessibilityIdentifier: "\(identifierPrefix).option.no"
                    )
                ],
                selectedID: selectionBinding,
                errorKey: viewModel.errorKey,
                groupAccessibilityIdentifier: "\(identifierPrefix).radioGroup",
                errorAccessibilityIdentifier: "\(identifierPrefix).error"
            )

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selection?.id },
            set: { viewModel.selection = $0.flatMap(LandingStorageOption.init(rawValue:)) }
        )
    }
}

#Preview("English") {
    LandingStorageView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    LandingStorageView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    LandingStorageView(referenceNumber: "A1234520260727150815", router: CatchRecordRouter())
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
