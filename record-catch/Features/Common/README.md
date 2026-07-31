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

## Demo screen

- `Views/TripFormDemoView.swift` composes all reusable controls in one GDS-style flow.

## Data source (stub)

- `Data/PortOptionProvider.swift` provides static options now and can be replaced by SwiftData-backed options later.
