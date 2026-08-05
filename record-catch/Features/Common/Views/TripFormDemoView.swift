import SwiftUI

struct TripFormDemoView: View {
    @State private var startedToday: Bool?
    @State private var departureDate = DateEntryValue()
    @State private var returnDate = DateEntryValue()
    @State private var portQuery = ""
    @State private var selectedPort: String?
    @State private var didAttemptSubmit = false
    @State private var password = ""

    private let portProvider: PortOptionProviding = StubPortOptionProvider()

    private let previousSubmissions: [SubmissionRow] = [
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .submitted),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .amended),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent),
        SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .late)
    ]

    private let statusHelpItems: [HelpItem] = [
        HelpItem(heading: "Unsent:", description: "Saved on your device and not yet submitted."),
        HelpItem(heading: "Submitted:", description: "Received by the MMO."),
        HelpItem(heading: "Amended:", description: "This record was changed after it was submitted."),
        HelpItem(heading: "Late:", description: "This record was received by the MMO after the required reporting timeframe.")
    ]

    private var isFormValid: Bool {
        startedToday != nil
            && DateEntryField.parsedDate(from: departureDate) != nil
            && DateEntryField.parsedDate(from: returnDate) != nil
            && selectedPort != nil
    }

    var body: some View {
        ViewTemplate(title: "Trip start") {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("A1234520260727150815")
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.textSecondary)

                TitleText(text: "Did your trip start and finish today?")

                ParagraphText(text: "Select yes if you're recording today's trip now.", isHint: true)
                ParagraphText(text: "Select no if you're recording a trip from another day - you'll then enter the dates.", isHint: true)

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    RadioOption(title: "Yes", isSelected: startedToday == true) {
                        startedToday = true
                    }
                    RadioOption(title: "No", isSelected: startedToday == false) {
                        startedToday = false
                    }

                    if didAttemptSubmit && startedToday == nil {
                        Text("Select whether your trip started and finished today")
                            .font(AppTypography.error)
                            .foregroundStyle(AppColors.errorRed)
                    }
                }

                DateEntryField(
                    title: "When did you leave for your trip?",
                    hint: "For example, 31/03/2020",
                    value: $departureDate,
                    didAttemptSubmit: didAttemptSubmit
                )

                DateEntryField(
                    title: "When did you return from your trip?",
                    hint: "For example, 31/03/2020",
                    value: $returnDate,
                    didAttemptSubmit: didAttemptSubmit
                )

                TextInputField(
                    label: "Password",
                    isSecure: true,
                    isRequired: false,
                    text: $password
                )

                PrimaryButton(title: "Save and continue") {
                    didAttemptSubmit = true
                }

                if didAttemptSubmit && isFormValid {
                    Text("Ready to continue")
                        .font(AppTypography.bodySmall)
                        .foregroundStyle(AppColors.govGreen)
                }

                Divider()
                    .overlay(AppColors.divider)

                TitleText(text: "Your trips")
                ParagraphText(text: "View trips you've already submitted.")
                ParagraphText(text: "Select a departure date to see the details you recorded.")

                SubmissionsTable(rows: previousSubmissions)

                ExpandableHelpSection(
                    title: "Understanding catch record statuses",
                    items: statusHelpItems
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
    TripFormDemoView()
}
