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

    /// Minimum width the 4-column table needs before columns clip; used to keep
    /// the horizontal-scroll reflow legible at accessibility text sizes.
    private static let tableReflowMinWidth: CGFloat = 560

    /// Stubbed page/total counts for this UI-only phase. Injectable so previews
    /// can demonstrate the multi-page pagination (Previous/Next arrows) without
    /// changing the default single-page production behaviour.
    private let currentPage: Int
    private let totalPages: Int
    private let totalItems: Int

    init(currentPage: Int = 1, totalPages: Int = 1, totalItems: Int = 4) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.totalItems = totalItems
    }

    // Stubbed, static trips for this UI-only phase.
    private let rows: [SubmissionRow] = [
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .submitted, createdBy: "J.Smith"),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .amended, createdBy: "J.Smith"),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith"),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .late, createdBy: "J.Smith")
    ]

    // Stubbed single page of results.
    private var paginationState: PaginationState {
        PaginationState(
            currentPage: currentPage,
            totalPages: totalPages,
            pageSize: 4,
            totalItems: totalItems
        )
    }

    var body: some View {
        ViewTemplate(
            title: languageStore.localized("home.title"),
            warning: WarningBox(tagKey: "home.warning.tag", messageKey: "home.warning.message")
        ) {
            content
                .environment(\.locale, languageStore.language.locale)
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

            tripsTable

            PaginationControls(state: paginationState)

            ExpandableHelpSection(
                title: languageStore.localized("home.help.title"),
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
                // Inert in this UI-only phase — navigates nowhere yet.
            }
            .accessibilityIdentifier("Home.createRecordButton")
        }
    }

    // Reflow strategy: at accessibility sizes the 4-column table would clip, so
    // it is placed inside a horizontal ScrollView (with a sensible minimum
    // width) keeping the date link + status visible. At normal sizes it fills
    // the available width as usual.
    @ViewBuilder
    private var tripsTable: some View {
        let table = SubmissionsTable(
            rows: rows,
            headerEndDate: languageStore.localized("home.table.header.endDate"),
            headerVessel: languageStore.localized("home.table.header.vessel"),
            headerStatus: languageStore.localized("home.table.header.status"),
            headerCreatedBy: languageStore.localized("home.table.header.createdBy"),
            viewSubmissionFormat: languageStore.localized("home.table.viewSubmission")
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
}

#Preview("Pagination – multiple pages") {
    // Injects a multi-page state so the GDS Previous/Next arrows are visible.
    HomeView(currentPage: 2, totalPages: 5, totalItems: 20)
        .environment(AppLanguageStore.preview)
}

#Preview("Welsh") {
    HomeView()
        .environment({
            let store = AppLanguageStore.preview
            store.language = .welsh
            return store
        }())
}

#Preview("Max Dynamic Type") {
    HomeView()
        .environment(AppLanguageStore.preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}
