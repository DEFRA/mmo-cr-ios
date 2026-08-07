import SwiftUI

// NOTE: This is a component showcase only. The production "Your trips" screen is
// `HomeView` (Features/Home/Views/HomeView.swift), which supersedes this demo.
struct TripsOverviewDemoView: View {
    private let rows: [SubmissionRow] = [
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .submitted, createdBy: "J.Smith"),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .amended, createdBy: "J.Smith"),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith"),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .late, createdBy: "J.Smith")
    ]

    var body: some View {
        ViewTemplate(title: "Your trips") {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                ParagraphText(text: "View trips you've already submitted.")
                ParagraphText(text: "Select an end date to see the details you recorded.")
                ParagraphText(text: "Note: You can only add new trips and view your account settings on the web service, not in this app.")

                SubmissionsTable(
                    rows: rows,
                    headerEndDate: "Trip end date",
                    headerVessel: "Vessel",
                    headerStatus: "Status",
                    headerCreatedBy: "Created by"
                )

                ExpandableHelpSection(
                    title: "Understanding catch record statuses",
                    items: [
                        HelpItem(heading: "Unsent:", description: "Saved on your device and not yet submitted."),
                        HelpItem(heading: "Submitted:", description: "Received by the MMO."),
                        HelpItem(heading: "Amended:", description: "This record was changed after it was submitted."),
                        HelpItem(heading: "Late:", description: "This record was received by the MMO after the required reporting timeframe.")
                    ]
                )

                PrimaryButton(title: "Create a new catch record") {
                    // Demo action for component showcase.
                }
            }
            .padding(AppSpacing.medium)
        }
    }
}

#Preview {
    TripsOverviewDemoView()
}
