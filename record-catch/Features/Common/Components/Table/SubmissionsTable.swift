import SwiftUI

struct SubmissionRow: Identifiable, Equatable {
    let id = UUID()
    let dateText: String
    let vesselName: String
    let status: SubmissionStatus
}

enum SubmissionStatus: String, CaseIterable {
    case submitted = "Submitted"
    case amended = "Amended"
    case unsent = "Unsent"
    case late = "Late"

    var backgroundColor: Color {
        switch self {
        case .submitted:
            return AppColors.statusSubmittedBackground
        case .amended:
            return AppColors.statusAmendedBackground
        case .unsent:
            return AppColors.statusUnsentBackground
        case .late:
            return AppColors.statusLateBackground
        }
    }

    var textColor: Color {
        switch self {
        case .submitted:
            return AppColors.statusSubmittedText
        case .amended:
            return AppColors.statusAmendedText
        case .unsent:
            return AppColors.statusUnsentText
        case .late:
            return AppColors.statusLateText
        }
    }
}

struct SubmissionsTable: View {
    let rows: [SubmissionRow]
    let onDateTapped: (SubmissionRow) -> Void

    init(rows: [SubmissionRow], onDateTapped: @escaping (SubmissionRow) -> Void = { _ in }) {
        self.rows = rows
        self.onDateTapped = onDateTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                SubmissionTableRow(row: row) {
                    onDateTapped(row)
                }

                if index < rows.count - 1 {
                    Divider()
                        .overlay(AppColors.divider)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(AppColors.divider, lineWidth: 1)
        )
    }
}

private struct SubmissionTableRow: View {
    let row: SubmissionRow
    let onDateTapped: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Button(action: onDateTapped) {
                Text(row.dateText)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.linkText)
                    .underline()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View submission for \(row.dateText)")

            Text(row.vesselName)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SubmissionStatusTag(status: row.status)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.small)
    }
}

private struct SubmissionStatusTag: View {
    let status: SubmissionStatus

    var body: some View {
        Text(status.rawValue)
            .font(AppTypography.bodySmall)
            .foregroundStyle(status.textColor)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .background(status.backgroundColor)
    }
}

#Preview {
    SubmissionsTable(
        rows: [
            SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .submitted),
            SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .amended),
            SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent),
            SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .late)
        ]
    )
    .padding()
}
