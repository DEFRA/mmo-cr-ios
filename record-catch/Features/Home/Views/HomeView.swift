//
//  HomeView.swift
//  record-catch
//
//  UI-only bilingual Home / "Your trips" screen, rendered inside ViewTemplate.
//  Production screen for the trips overview; supersedes TripsOverviewDemoView.
//  All data is stubbed/static — no auth, networking, persistence, sync or real
//  navigation in this phase.
//

import SwiftUI

struct HomeView: View {

    @Environment(AppLanguageStore.self) private var languageStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(CatchRecordRouter.self) private var router

    /// Minimum width the 4-column table needs before columns clip; used to keep
    /// the horizontal-scroll reflow legible at accessibility text sizes.
    private static let tableReflowMinWidth: CGFloat = 560

    /// The number of rows shown per pagination page.
    private static let pageSize = 4

    /// The 1-based page currently shown. Injectable so previews can demonstrate the multi-page
    /// pagination (Previous/Next arrows); there is no in-app paging interaction yet, so this stays
    /// fixed for a given screen instance.
    private let currentPage: Int

    /// Loads the merged local-drafts + server-records list (see ADR-0015). Injectable so previews
    /// and UI tests can seed a deterministic `RecordsProviding` without a real `ModelContainer`.
    @State private var viewModel: HomeViewModel

    init(
        currentPage: Int = 1,
        recordsProvider: RecordsProviding? = nil
    ) {
        self.currentPage = currentPage
        let provider = recordsProvider ?? MergingRecordsRepository(draftStore: InMemoryCatchRecordDraftStore())
        _viewModel = State(wrappedValue: HomeViewModel(recordsProvider: provider))
    }

    /// Derived from the live `viewModel.rows` count, so the "showing X to Y of Z" text and the
    /// page-number strip update whenever a draft is added, saved further or deleted (see
    /// `HomeViewModel.load()`) instead of being fixed at view construction.
    private var paginationState: PaginationState {
        PaginationState(currentPage: currentPage, itemCount: viewModel.rows.count, pageSize: Self.pageSize)
    }

    var body: some View {
        ViewTemplate(
            title: languageStore.localized("home.title"),
            warning: WarningBox(tagKey: "home.warning.tag", messageKey: "home.warning.message")
        ) {
            content
                .environment(\.locale, languageStore.language.locale)
        }
        .task { await viewModel.load() }
        // Reload whenever the journey stack collapses back to Home (e.g. a resumed draft was
        // saved further, or deleted), so the list reflects the latest on-device state without
        // requiring an app relaunch.
        .onChange(of: router.path) { _, newPath in
            guard newPath.isEmpty else { return }
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ParagraphText(text: languageStore.localized("home.intro.viewSubmitted"))
                ParagraphText(text: languageStore.localized("home.intro.selectDate"))
                ParagraphText(text: languageStore.localized("home.intro.webOnly"))
            }

            recordsListSection

            howToRecordSection

            ExpandableHelpSection(
                title: languageStore.localized("home.help.title"),
                accessibilityIdentifier: "Home.statusHelp",
                items: [
                    HelpItem(
                        heading: languageStore.localized("home.help.unsent.heading"),
                        description: languageStore.localized("home.help.unsent.description")
                    ),
                    HelpItem(
                        heading: languageStore.localized("home.help.submitted.heading"),
                        description: languageStore.localized("home.help.submitted.description")
                    ),
                    HelpItem(
                        heading: languageStore.localized("home.help.amended.heading"),
                        description: languageStore.localized("home.help.amended.description")
                    ),
                    HelpItem(
                        heading: languageStore.localized("home.help.late.heading"),
                        description: languageStore.localized("home.help.late.description")
                    )
                ]
            )

            PrimaryButton(title: languageStore.localized("home.createRecord.button")) {
                router.startNew()
            }
            .accessibilityIdentifier("Home.createRecordButton")
        }
    }

    /// The records list itself, or an explicit loading/empty/error state — never an indefinite
    /// spinner (see the accessibility instructions).
    @ViewBuilder
    private var recordsListSection: some View {
        switch viewModel.loadState {
        case .loading:
            HStack(spacing: AppSpacing.small) {
                ProgressView()
                Text(languageStore.localized("home.records.loading"))
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("Home.records.loading")
        case .empty:
            Text(languageStore.localized("home.records.empty"))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityIdentifier("Home.records.empty")
        case .failed:
            recordsErrorBanner
        case .loaded:
            tripsTable
            PaginationControls(state: paginationState)
        }
    }

    private var recordsErrorBanner: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .top, spacing: AppSpacing.xSmall) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(AppColors.errorRed)
                    .accessibilityHidden(true)
                Text(languageStore.localized("home.records.error"))
                    .font(AppTypography.error)
                    .foregroundStyle(AppColors.errorRed)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(languageStore.localized("a11y.errorPrefix")) \(languageStore.localized("home.records.error"))"
            )

            SecondaryButton(title: languageStore.localized("home.records.error.retry")) {
                Task { await viewModel.load() }
            }
            .accessibilityIdentifier("Home.records.retry")
        }
        .accessibilityIdentifier("Home.records.error")
    }

    /// "How to record a catch" — a richer disclosure section (multiple
    /// sub-headings, paragraphs and a bullet list) explaining what/when to
    /// record and how to get help. Uses the generic `content:` initializer of
    /// `ExpandableHelpSection` since its shape doesn't fit the flat
    /// heading+paragraph `HelpItem` list used by the status-help section.
    private var howToRecordSection: some View {
        ExpandableHelpSection(
            title: languageStore.localized("home.howToRecord.title"),
            accessibilityIdentifier: "Home.howToRecord"
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                howToRecordHeading(languageStore.localized("home.howToRecord.whatYouNeedToDo.heading"))
                ParagraphText(text: languageStore.localized("home.howToRecord.whatYouNeedToDo.body1"))
                ParagraphText(text: languageStore.localized("home.howToRecord.whatYouNeedToDo.body2"))

                howToRecordHeading(languageStore.localized("home.howToRecord.whenToCreate.heading"))
                ParagraphText(text: languageStore.localized("home.howToRecord.whenToCreate.intro"))
                howToRecordBulletList([
                    languageStore.localized("home.howToRecord.whenToCreate.bullet.quota"),
                    languageStore.localized("home.howToRecord.whenToCreate.bullet.nonQuota"),
                    languageStore.localized("home.howToRecord.whenToCreate.bullet.icesBoundary")
                ])
                ParagraphText(text: languageStore.localized("home.howToRecord.whenToCreate.deadline"))

                howToRecordHeading(languageStore.localized("home.howToRecord.icesAreas.heading"))
                ParagraphText(text: languageStore.localized("home.howToRecord.icesAreas.body1"))
                ParagraphText(text: languageStore.localized("home.howToRecord.icesAreas.body2"))

                howToRecordHeading(languageStore.localized("home.howToRecord.getHelp.heading"))
                ParagraphText(text: languageStore.localized("home.howToRecord.getHelp.phone"))
                ParagraphText(text: languageStore.localized("home.howToRecord.getHelp.callCost"))
                ParagraphText(text: languageStore.localized("home.howToRecord.getHelp.outOfHours"))
            }
        }
    }

    private func howToRecordHeading(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.bodySmall)
            .fontWeight(.bold)
            .foregroundStyle(AppColors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    /// Renders a simple bullet list, matching the established "•" + text row
    /// pattern used by `SubmissionConfirmationView`/`SubmissionSuccessView`.
    private func howToRecordBulletList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: AppSpacing.xSmall) {
                    Text("•")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                    ParagraphText(text: item)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    // Reflow strategy: at accessibility sizes the 4-column table would clip, so
    // it is placed inside a horizontal ScrollView (with a sensible minimum
    // width) keeping the date link + status visible. At normal sizes it fills
    // the available width as usual.
    @ViewBuilder
    private var tripsTable: some View {
        let table = SubmissionsTable(
            rows: viewModel.rows,
            headerEndDate: languageStore.localized("home.table.header.endDate"),
            headerVessel: languageStore.localized("home.table.header.vessel"),
            headerStatus: languageStore.localized("home.table.header.status"),
            headerCreatedBy: languageStore.localized("home.table.header.createdBy"),
            viewSubmissionFormat: languageStore.localized("home.table.viewSubmission"),
            onDateTapped: { row in
                if let route = CatchRecordRouting.entryRoute(for: row) {
                    router.push(route)
                }
            }
        )

        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal, showsIndicators: true) {
                table.frame(minWidth: Self.tableReflowMinWidth, alignment: .leading)
            }
        } else {
            table
        }
    }
}

#Preview("English") {
    HomeView()
        .environment(AppLanguageStore.preview)
        .environment(CatchRecordRouter())
}

#Preview("Pagination – multiple pages") {
    // Injects 20 stubbed rows (5 pages at pageSize 4) so the GDS Previous/Next arrows are visible.
    let rows = (1...20).map { index in
        SubmissionRow(
            dateText: "20 Nov 2020",
            vesselName: "ACHILLES \(index)",
            status: .submitted,
            createdBy: "J.Smith",
            sortDate: Date(timeIntervalSince1970: TimeInterval(index))
        )
    }
    HomeView(currentPage: 2, recordsProvider: StubRecordsProvider(rows: rows))
        .environment(AppLanguageStore.preview)
        .environment(CatchRecordRouter())
}

#Preview("Welsh") {
    HomeView()
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
        .environment(CatchRecordRouter())
}

#Preview("Max Dynamic Type") {
    HomeView()
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
        .environment(CatchRecordRouter())
}
