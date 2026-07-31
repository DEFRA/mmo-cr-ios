import SwiftUI

struct TripsOverviewDemoView: View {
    private let rows: [SubmissionRow] = [
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .submitted),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .amended),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .late)
    ]

    var body: some View {
        ViewTemplate(title: "Your trips") {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                ParagraphText(text: "View trips you've already submitted.")
                ParagraphText(text: "Select a departure date to see the details you recorded.")
                ParagraphText(text: "Note: You can only add new trips and view your account settings on the web service, not in this app.")

                SubmissionsTable(rows: rows)

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
