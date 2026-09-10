import SwiftUI

nonisolated struct SubmissionRow: Identifiable, Equatable {
    let id = UUID()
    let dateText: String
    let vesselName: String
    let status: SubmissionStatus
    let createdBy: String
    /// The persisted draft this row resolves to, when it is a local **Unsent** record (see
    /// ADR-0014/0015). `nil` for server-sourced rows and for rows built before persistence existed
    /// (e.g. hand-built preview/test rows), which stay content-equal to one another as before.
    let localID: UUID?
    /// Used only for ordering the merged Home list newest-first (see `MergingRecordsRepository`);
    /// never rendered and deliberately excluded from equality/hashing below.
    let sortDate: Date

    init(
        dateText: String,
        vesselName: String,
        status: SubmissionStatus,
        createdBy: String,
        localID: UUID? = nil,
        sortDate: Date = .distantPast
    ) {
        self.dateText = dateText
        self.vesselName = vesselName
        self.status = status
        self.createdBy = createdBy
        self.localID = localID
        self.sortDate = sortDate
    }

    /// Content-based equality: two rows with the same content are equal even if
    /// their randomly-generated `id`s differ (the `id` is for `Identifiable`/
    /// `ForEach` identity only, not semantic equality). `localID`/`sortDate` are deliberately
    /// excluded — they identify *where the data came from* and *how to order it*, not what is
    /// shown, so this stays consistent with every existing call site/test that predates them.
    static func == (lhs: SubmissionRow, rhs: SubmissionRow) -> Bool {
        lhs.dateText == rhs.dateText
            && lhs.vesselName == rhs.vesselName
            && lhs.status == rhs.status
            && lhs.createdBy == rhs.createdBy
    }
}

extension SubmissionRow: Hashable {
    /// Hashes on content only (not `id`), to stay consistent with the custom
    /// content-based `Equatable` conformance above. This lets `SubmissionRow`
    /// be carried as an associated value on `CatchRecordRoute` (see ADR-0003).
    func hash(into hasher: inout Hasher) {
        hasher.combine(dateText)
        hasher.combine(vesselName)
        hasher.combine(status)
        hasher.combine(createdBy)
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
        // No-op default: intentionally empty for previews/tests that render the table without
        // wiring row-tap navigation; real call sites (e.g. `HomeView`) always supply a handler.
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

            Rectangle()
                .fill(AppColors.divider)
                .frame(height: 2)

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
        .padding(.vertical, AppSpacing.small)
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
        .padding(.vertical, AppSpacing.medium)
    }
}

private struct SubmissionStatusTag: View {
    let status: SubmissionStatus

    var body: some View {
        Text(status.rawValue)
            .font(AppTypography.bodySmall)
            .foregroundStyle(status.textColor)
            .lineLimit(1)
            .fixedSize()
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
