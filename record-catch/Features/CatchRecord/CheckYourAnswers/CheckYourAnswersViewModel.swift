import Foundation

/// View model for the "Check your answers" screen, ending the "Create a catch record" journey.
///
/// Presents every value captured in `CatchRecordDraft` as four ordered, read-only sections — Trip,
/// Gear used, Species caught, Species not landed — each row pairing a label with an
/// already-formatted display value and a `changeRoute` that returns the user to the screen where
/// that value was captured. Purely a projection of the draft: it holds no mutable state of its own
/// and performs no validation, so it is directly unit-testable against a seeded `CatchRecordDraft`.
@MainActor
@Observable
final class CheckYourAnswersViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    private let router: CatchRecordRouter
    private let draft: CatchRecordDraft

    init(referenceNumber: String, router: CatchRecordRouter, draft: CatchRecordDraft) {
        self.referenceNumber = referenceNumber
        self.router = router
        self.draft = draft
    }

    /// A single labelled fact about the trip, with the route its "Change" link returns to.
    struct Row: Identifiable, Hashable {
        let id: String
        /// String Catalog key for the row's label.
        let labelKey: String
        /// The already-formatted value to display (dates, names and weights are pre-formatted so
        /// the view performs no further formatting logic).
        let value: String
        let changeRoute: CatchRecordRoute
    }

    /// A titled group of rows, rendered under its own heading.
    struct Section: Identifiable, Hashable {
        let id: String
        /// String Catalog key for the section heading.
        let titleKey: String
        let rows: [Row]
    }

    /// Long-style, numeric-free date formatting (e.g. "27 July 2026") shared by both trip dates.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    /// The four sections of the journey summary, in display order. Trip and Gear used are always
    /// present (even with zero rows, if nothing has been captured yet); the species sections are
    /// omitted entirely when their list is empty.
    var sections: [Section] {
        var result = [tripSection, gearSection]
        if !speciesCaughtRows.isEmpty {
            result.append(
                Section(
                    id: "speciesCaught",
                    titleKey: "catchRecord.checkYourAnswers.section.speciesCaught",
                    rows: speciesCaughtRows
                )
            )
        }
        if !speciesNotLandedRows.isEmpty {
            result.append(
                Section(
                    id: "speciesNotLanded",
                    titleKey: "catchRecord.checkYourAnswers.section.speciesNotLanded",
                    rows: speciesNotLandedRows
                )
            )
        }
        return result
    }

    /// Pushes the destination for a row's "Change" control.
    func change(to route: CatchRecordRoute) {
        router.push(route)
    }

    /// Confirms the summary and advances to the final submission-confirmation screen.
    func submit() {
        router.push(.submissionConfirmation(referenceNumber: referenceNumber))
    }

    // MARK: - Trip

    private var tripSection: Section {
        Section(id: "trip", titleKey: "catchRecord.checkYourAnswers.section.trip", rows: tripRows)
    }

    private var tripRows: [Row] {
        var rows: [Row] = []

        if let vessel = draft.vessel {
            rows.append(
                Row(
                    id: "trip.vessel",
                    labelKey: "catchRecord.checkYourAnswers.label.vessel",
                    value: vessel,
                    changeRoute: .selectVessel
                )
            )
        }

        if let vessel = draft.vessel, let departureDate = draft.departureDate {
            rows.append(
                Row(
                    id: "trip.departureDate",
                    labelKey: "catchRecord.checkYourAnswers.label.departureDate",
                    value: Self.dateFormatter.string(from: departureDate),
                    changeRoute: .tripDate(
                        phase: .departure,
                        vessel: vessel,
                        referenceNumber: referenceNumber,
                        departureDate: departureDate
                    )
                )
            )
        }

        if let vessel = draft.vessel, let returnDate = draft.returnDate {
            rows.append(
                Row(
                    id: "trip.returnDate",
                    labelKey: "catchRecord.checkYourAnswers.label.returnDate",
                    value: Self.dateFormatter.string(from: returnDate),
                    changeRoute: .tripDate(
                        phase: .return,
                        vessel: vessel,
                        referenceNumber: referenceNumber,
                        departureDate: draft.departureDate
                    )
                )
            )
        }

        if let vessel = draft.vessel, let departurePort = draft.departurePort {
            rows.append(
                Row(
                    id: "trip.departurePort",
                    labelKey: "catchRecord.checkYourAnswers.label.departurePort",
                    value: departurePort.name,
                    changeRoute: .selectPort(phase: .departure, vessel: vessel, referenceNumber: referenceNumber)
                )
            )
        }

        if let vessel = draft.vessel, let returnPort = draft.returnPort {
            rows.append(
                Row(
                    id: "trip.returnPort",
                    labelKey: "catchRecord.checkYourAnswers.label.returnPort",
                    value: returnPort.name,
                    changeRoute: .selectPort(phase: .return, vessel: vessel, referenceNumber: referenceNumber)
                )
            )
        }

        if let vessel = draft.vessel, let gear = draft.gear, let statisticalArea = draft.statisticalArea {
            rows.append(
                Row(
                    id: "trip.statisticalArea",
                    labelKey: "catchRecord.checkYourAnswers.label.statisticalArea",
                    value: statisticalArea,
                    changeRoute: .catchLocation(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
                )
            )
        }

        return rows
    }

    // MARK: - Gear used

    private var gearSection: Section {
        Section(id: "gear", titleKey: "catchRecord.checkYourAnswers.section.gear", rows: gearRows)
    }

    private var gearRows: [Row] {
        guard let vessel = draft.vessel, let gear = draft.gear else { return [] }
        // Required measurements are captured on the gear-measurements screen; variable (per-trip)
        // measurements are captured on the select-gear screen, so each "Change" returns the user to
        // the screen where that value was entered.
        let measurementsRoute = CatchRecordRoute.gearMeasurements(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
        let selectGearRoute = CatchRecordRoute.selectGear(vessel: vessel, referenceNumber: referenceNumber)

        var rows: [Row] = [
            Row(
                id: "gear.name",
                labelKey: "catchRecord.checkYourAnswers.label.gear",
                value: gear.name,
                changeRoute: measurementsRoute
            )
        ]

        for measurement in gear.requiredMeasurements {
            guard let value = measurement.value else { continue }
            rows.append(
                Row(
                    id: "gear.measurement.\(measurement.id)",
                    labelKey: measurement.labelKey,
                    value: String(value),
                    changeRoute: measurementsRoute
                )
            )
        }

        for measurement in gear.variableMeasurements {
            guard let value = measurement.value else { continue }
            rows.append(
                Row(
                    id: "gear.variableMeasurement.\(measurement.id)",
                    labelKey: measurement.labelKey,
                    value: String(value),
                    changeRoute: selectGearRoute
                )
            )
        }

        return rows
    }

    // MARK: - Species caught / not landed

    private var speciesCaughtRows: [Row] {
        guard let vessel = draft.vessel, let gear = draft.gear else { return [] }
        let changeRoute = CatchRecordRoute.recordSpeciesWeights(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
        return draft.speciesCaught.flatMap {
            weightRows(
                for: $0,
                idPrefix: "speciesCaught.\($0.id)",
                aboveLabelKey: "catchRecord.checkYourAnswers.label.weightAbove",
                changeRoute: changeRoute
            )
        }
    }

    private var speciesNotLandedRows: [Row] {
        let changeRoute = CatchRecordRoute.landingStorageSpecies(referenceNumber: referenceNumber)
        return draft.speciesNotLanded.flatMap {
            weightRows(
                for: $0,
                idPrefix: "speciesNotLanded.\($0.id)",
                aboveLabelKey: "catchRecord.checkYourAnswers.label.weightNotLanded",
                changeRoute: changeRoute
            )
        }
    }

    /// Builds the name + weight rows for a single species, sharing one Change route across all of
    /// a species' rows since a single Change action edits that whole species entry.
    private func weightRows(
        for species: SpeciesOption,
        idPrefix: String,
        aboveLabelKey: String,
        changeRoute: CatchRecordRoute
    ) -> [Row] {
        var rows: [Row] = [
            Row(
                id: "\(idPrefix).name",
                labelKey: "catchRecord.checkYourAnswers.label.speciesName",
                value: species.name,
                changeRoute: changeRoute
            )
        ]

        if !species.weightAboveMinimumKg.isEmpty {
            rows.append(
                Row(
                    id: "\(idPrefix).above",
                    labelKey: aboveLabelKey,
                    value: "\(species.weightAboveMinimumKg) kg",
                    changeRoute: changeRoute
                )
            )
        }

        if let below = species.weightBelowMinimumKg, !below.isEmpty {
            rows.append(
                Row(
                    id: "\(idPrefix).below",
                    labelKey: "catchRecord.checkYourAnswers.label.weightBelow",
                    value: "\(below) kg",
                    changeRoute: changeRoute
                )
            )
        }

        if let discarded = species.weightLegallyDiscardedKg, !discarded.isEmpty {
            rows.append(
                Row(
                    id: "\(idPrefix).discarded",
                    labelKey: "catchRecord.checkYourAnswers.label.weightDiscarded",
                    value: "\(discarded) kg",
                    changeRoute: changeRoute
                )
            )
        }

        return rows
    }
}
