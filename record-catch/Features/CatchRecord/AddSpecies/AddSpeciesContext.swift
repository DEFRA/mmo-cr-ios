import Foundation

/// Which context the Add-species screen was entered from.
///
/// Both contexts push the same `CatchRecordRoute.addSpecies` screen, but GOV.UK requires
/// context-specific validation copy ("be specific" — see the error-message component guidance), so
/// this drives which pair of messages `AddSpeciesValidation` returns (see plan Q3).
nonisolated enum AddSpeciesContext: Hashable {
    /// First-time entry: the user has no favourite species yet (`CatchRecordRouting.speciesEntryRoute`).
    case firstTime
    /// "Add a species" / "Add another species", reached while already recording this trip's catch
    /// (from `RecordSpeciesWeightsViewModel.addSpecies()` or after emptying a gear's species list
    /// on `RemoveSpeciesViewModel`).
    case addAnother
}
