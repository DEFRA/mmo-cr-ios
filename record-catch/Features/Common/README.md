# Common UI Components

This folder contains reusable GDS-inspired SwiftUI components and shared design tokens.

## Design system

- `DesignSystem/AppColors.swift`: shared color palette.
- `DesignSystem/AppTypography.swift`: SF-based GOV.UK-like typography tokens.
- `DesignSystem/AppSpacing.swift`: spacing and control-size tokens.

## Components

- `Components/Typography/TitleText.swift`: reusable page title text.
- `Components/Typography/ParagraphText.swift`: reusable body/hint text.
- `Components/Form/PrimaryButton.swift`: primary action button.
- `Components/Form/RadioOption.swift`: radio-style option row.
- `Components/Form/DateEntryField.swift`: day/month/year date input with inline validation.
- `Components/Form/SearchDropdownField.swift`: list-only search field with dropdown results.
- `Components/Form/TextInputField.swift`: text input that also supports secure password entry.

## Data source (stub)

- `Data/PortOptionProvider.swift` provides static options now and can be replaced by SwiftData-backed options later.
- `Data/RecordsRepository.swift` merges local, on-device-persisted Unsent drafts (see
  [ADR-0014](../../../docs/adr/0014-catch-record-draft-persistence.md)) with a fixed server-record
  stub, newest first, for Home's trips table (see
  [ADR-0015](../../../docs/adr/0015-home-merged-records-list.md)).
- `Components/Table/SubmissionsTable.swift`'s `SubmissionRow` carries an optional `localID: UUID?`
  (set for a local Unsent row so it can be resumed/deleted) and a `sortDate: Date` (ordering only);
  both are excluded from its existing content-based equality/hashing.
