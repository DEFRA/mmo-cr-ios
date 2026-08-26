import SwiftUI

/// "Check your answers" — the final read-only summary ending the "Create a catch record" journey.
///
/// Renders every value captured in `CatchRecordDraft` as four sections (Trip, Gear used, Species
/// caught, Species not landed), each row pairing a label and value with a "Change" control that
/// jumps back to the screen where that value was captured (`CheckYourAnswersViewModel.change(to:)`).
struct CheckYourAnswersView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @State private var viewModel: CheckYourAnswersViewModel

    init(referenceNumber: String, router: CatchRecordRouter, draft: CatchRecordDraft) {
        _viewModel = State(wrappedValue: CheckYourAnswersViewModel(
            referenceNumber: referenceNumber,
            router: router,
            draft: draft
        ))
    }

    private let identifierPrefix = "CatchRecord.checkYourAnswers"

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

            TitleText(text: languageStore.localized("catchRecord.checkYourAnswers.heading"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).heading")

            ForEach(viewModel.sections) { section in
                sectionView(section)
            }

            PrimaryButton(title: languageStore.localized("catchRecord.saveContinue")) {
                viewModel.submit()
            }
            .accessibilityIdentifier("\(identifierPrefix).saveContinue")
        }
    }

    @ViewBuilder
    private func sectionView(_ section: CheckYourAnswersViewModel.Section) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(languageStore.localized(section.titleKey))
                .font(AppTypography.footerHeading)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("\(identifierPrefix).section.\(section.id)")

            ForEach(section.rows) { row in
                rowView(row)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: CheckYourAnswersViewModel.Row) -> some View {
        let label = languageStore.localized(row.labelKey)
        HStack(alignment: .top, spacing: AppSpacing.small) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(label)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)
                Text(row.value)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer(minLength: AppSpacing.small)

            Button {
                viewModel.change(to: row.changeRoute)
            } label: {
                Text(languageStore.localized("catchRecord.checkYourAnswers.change"))
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.linkText)
                    .underline()
                    .frame(minWidth: AppControlSize.buttonHeight, minHeight: AppControlSize.buttonHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
            .accessibilityLabel(
                "\(languageStore.localized("catchRecord.checkYourAnswers.change")) \(label)"
            )
            .accessibilityIdentifier("\(identifierPrefix).change.\(row.id)")
        }
        .accessibilityElement(children: .contain)
    }
}

private func previewDraft() -> CatchRecordDraft {
    let draft = CatchRecordDraft()
    draft.vessel = "ACHILLES"
    draft.departureDate = Date()
    draft.returnDate = Date()
    draft.departurePort = PortOption(name: "Plymouth")
    draft.returnPort = PortOption(name: "Plymouth")
    draft.statisticalArea = "27.7.e"
    draft.gear = GearOption.seineNets
        .withRequiredMeasurements([
            GearMeasurement(id: "meshSize", labelKey: "catchRecord.gear.measurement.meshSize", value: 80)
        ])
        .withVariableMeasurements([
            GearMeasurement(id: "timesShot", labelKey: "catchRecord.gear.variableMeasurement.timesShot", value: 5)
        ])
    draft.speciesCaught = [SpeciesOption(id: "cod", name: "Atlantic cod (COD)", weightAboveMinimumKg: "250")]
    draft.speciesNotLanded = [SpeciesOption(id: "cod", name: "Atlantic cod (COD)", weightAboveMinimumKg: "5")]
    return draft
}

#Preview("English") {
    CheckYourAnswersView(
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: previewDraft()
    )
    .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    CheckYourAnswersView(
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: CatchRecordDraft()
    )
    .environment({
        let store = AppLanguageStore.preview
        store.language = .welsh
        return store
    }())
}

#Preview("Max Dynamic Type") {
    CheckYourAnswersView(
        referenceNumber: "A1234520260727150815",
        router: CatchRecordRouter(),
        draft: CatchRecordDraft()
    )
    .environment(AppLanguageStore.preview)
    .environment(\.dynamicTypeSize, .accessibility5)
}
