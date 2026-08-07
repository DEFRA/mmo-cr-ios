import SwiftUI

struct SubmissionRow: Identifiable, Equatable {
    let id = UUID()
    let dateText: String
    let vesselName: String
    let status: SubmissionStatus
    let createdBy: String

    /// Content-based equality: two rows with the same content are equal even if
    /// their randomly-generated `id`s differ (the `id` is for `Identifiable`/
    /// `ForEach` identity only, not semantic equality).
    static func == (lhs: SubmissionRow, rhs: SubmissionRow) -> Bool {
        lhs.dateText == rhs.dateText
            && lhs.vesselName == rhs.vesselName
            && lhs.status == rhs.status
            && lhs.createdBy == rhs.createdBy
    }
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
    let headerEndDate: String
    let headerVessel: String
    let headerStatus: String
    let headerCreatedBy: String
    /// Localised format for the date-link accessibility label, with one
    /// positional `%@` for the date (e.g. "View submission for %@").
    let viewSubmissionFormat: String
    let onDateTapped: (SubmissionRow) -> Void

    init(
        rows: [SubmissionRow],
        headerEndDate: String,
        headerVessel: String,
        headerStatus: String,
        headerCreatedBy: String,
        viewSubmissionFormat: String = "View submission for %@",
        onDateTapped: @escaping (SubmissionRow) -> Void = { _ in }
    ) {
        self.rows = rows
        self.headerEndDate = headerEndDate
        self.headerVessel = headerVessel
        self.headerStatus = headerStatus
        self.headerCreatedBy = headerCreatedBy
        self.viewSubmissionFormat = viewSubmissionFormat
        self.onDateTapped = onDateTapped
    }

    /// The ordered column-header titles rendered above the rows. Pure so the
    /// header composition (4 columns incl. Created by) can be unit tested.
    static func headerTitles(
        endDate: String,
        vessel: String,
        status: String,
        createdBy: String
    ) -> [String] {
        [endDate, vessel, status, createdBy]
    }

    var body: some View {
        VStack(spacing: 0) {
            SubmissionTableHeader(
                endDate: headerEndDate,
                vessel: headerVessel,
                status: headerStatus,
                createdBy: headerCreatedBy
            )

            Divider()
                .overlay(AppColors.divider)

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                SubmissionTableRow(
                    row: row,
                    index: index,
                    viewSubmissionFormat: viewSubmissionFormat
                ) {
                    onDateTapped(row)
                }

                if index < rows.count - 1 {
                    Divider()
                        .overlay(AppColors.divider)
                }
            }
        }
        .overlay(
            Rectangle()
                .stroke(AppColors.divider, lineWidth: 1)
        )
    }
}

private struct SubmissionTableHeader: View {
    let endDate: String
    let vessel: String
    let status: String
    let createdBy: String

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            headerCell(endDate, alignment: .leading)
            headerCell(vessel, alignment: .leading)
            headerCell(status, alignment: .leading)
            headerCell(createdBy, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, AppSpacing.small)
        .background(AppColors.surfaceMuted)
    }

    private func headerCell(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .font(AppTypography.bodySmall.weight(.bold))
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: alignment)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SubmissionTableRow: View {
    let row: SubmissionRow
    let index: Int
    let viewSubmissionFormat: String
    let onDateTapped: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Button(action: onDateTapped) {
                Text(row.dateText)
                    .font(AppTypography.bodySmall)
                    .foregroundStyle(AppColors.linkText)
                    .underline()
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: viewSubmissionFormat, row.dateText))
            .accessibilityIdentifier("Home.table.row.\(index).date")

            Text(row.vesselName)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SubmissionStatusTag(status: row.status)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.createdBy)
                .font(AppTypography.bodySmall)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .background(status.backgroundColor)
    }
}

#Preview {
    SubmissionsTable(
        rows: [
            SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .submitted, createdBy: "J.Smith"),
            SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .amended, createdBy: "J.Smith"),
            SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .unsent, createdBy: "J.Smith"),
            SubmissionRow(dateText: "20 Nov 2020", vesselName: "ACHILLES", status: .late, createdBy: "J.Smith")
        ],
        headerEndDate: "Trip end date",
        headerVessel: "Vessel",
        headerStatus: "Status",
        headerCreatedBy: "Created by"
    )
    .padding()
}
