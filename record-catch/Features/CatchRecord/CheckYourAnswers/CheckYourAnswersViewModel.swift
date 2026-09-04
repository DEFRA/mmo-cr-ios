import Foundation

/// View model for the "Check your answers" screen, ending the "Create a catch record" journey.
///
/// Presents every value captured in `CatchRecordDraft` as ordered, read-only sections — Trip, one
/// section **per selected gear** (that gear's details, its statistical area and the species caught
/// with it — see ADR-0011), then Species not landed — each row pairing a label with an
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
        /// The gear this row belongs to, when it is part of a per-gear section — `nil` for
        /// trip-level/species-not-landed rows. Used to build a gear-disambiguated accessibility
        /// label for the row's "Change" control, since the same field label (e.g. "Statistical
        /// area") repeats once per gear section (see GOV.UK Design System — Check answers: a
        /// summary-card's Change link must say what it changes).
        var gearName: String?
        /// Whether "Change" for this row should return straight to Check your answers once its
        /// onward mini-journey (which may re-enter the catch-location/species screens for this one
        /// gear) completes, rather than continuing through any other selected gears (see
        /// ADR-0011). True only for a gear's statistical-area and species-caught rows.
        var resumesAtCheckYourAnswers = false

        init(
            id: String,
            labelKey: String,
            value: String,
            changeRoute: CatchRecordRoute,
            gearName: String? = nil,
            resumesAtCheckYourAnswers: Bool = false
        ) {
            self.id = id
            self.labelKey = labelKey
            self.value = value
            self.changeRoute = changeRoute
            self.gearName = gearName
            self.resumesAtCheckYourAnswers = resumesAtCheckYourAnswers
        }
    }

    /// A titled group of rows, rendered under its own heading.
    struct Section: Identifiable, Hashable {
        let id: String
        /// String Catalog key for the section heading, looked up via `AppLanguageStore`. `nil`
        /// when `literalTitle` supplies the heading directly instead.
        let titleKey: String?
        /// A literal (non-localized) heading, used instead of `titleKey` when non-nil — e.g. a
        /// gear's name, which is untranslated reference data rather than app copy (mirrors how
        /// `Row.value` already shows raw gear/species names directly rather than via a catalog
        /// key).
        let literalTitle: String?
        let rows: [Row]

        init(id: String, titleKey: String, rows: [Row]) {
            self.id = id
            self.titleKey = titleKey
            self.literalTitle = nil
            self.rows = rows
        }

        init(id: String, literalTitle: String, rows: [Row]) {
            self.id = id
            self.titleKey = nil
            self.literalTitle = literalTitle
            self.rows = rows
        }
    }

    /// Long-style, numeric-free date formatting (e.g. "27 July 2026") shared by both trip dates.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    /// The journey summary's sections, in display order: Trip, then one section per selected gear
    /// (each only shown once its gear/vessel are known — see `gearCatchSections`), then Species not
    /// landed (omitted entirely when empty).
    var sections: [Section] {
        var result = [tripSection]
        result.append(contentsOf: gearCatchSections)
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

    /// Pushes the destination for a row's "Change" control, first recording whether the journey
    /// should return straight here (rather than continue through the normal multi-gear loop) once
    /// its onward mini-journey completes — see `CatchRecordDraft.returnToCheckYourAnswersAfterSpecies`
    /// and ADR-0011.
    func change(to route: CatchRecordRoute, resumingAtCheckYourAnswers: Bool = false) {
        draft.returnToCheckYourAnswersAfterSpecies = resumingAtCheckYourAnswers
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

        return rows
    }

    // MARK: - Per-gear sections (gear used, statistical area, species caught — see ADR-0011)

    /// One section per selected gear (`CatchRecordDraft.gearCatches`), titled by the gear's name.
    private var gearCatchSections: [Section] {
        guard let vessel = draft.vessel else { return [] }
        return draft.gearCatches.map { gearCatchSection(for: $0, vessel: vessel) }
    }

    private func gearCatchSection(for gearCatch: GearCatch, vessel: String) -> Section {
        Section(
            id: "gear.\(gearCatch.id)",
            literalTitle: gearCatch.gear.name,
            rows: gearCatchRows(for: gearCatch, vessel: vessel)
        )
    }

    private func gearCatchRows(for gearCatch: GearCatch, vessel: String) -> [Row] {
        let gear = gearCatch.gear
        // Required measurements are captured on the gear-measurements screen; variable (per-trip)
        // measurements are captured on the select-gear screen, so each "Change" returns the user to
        // the screen where that value was entered. The statistical area and species caught are
        // captured per gear (ADR-0011), so their "Change" returns straight to Check your answers
        // once saved, rather than continuing through any other selected gears.
        let measurementsRoute = CatchRecordRoute.gearMeasurements(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
        let selectGearRoute = CatchRecordRoute.selectGear(vessel: vessel, referenceNumber: referenceNumber)
        let locationRoute = CatchRecordRoute.catchLocation(gear: gear, vessel: vessel, referenceNumber: referenceNumber)
        let speciesRoute = CatchRecordRoute.recordSpeciesWeights(gear: gear, vessel: vessel, referenceNumber: referenceNumber)

        var rows: [Row] = [
            Row(
                id: "gear.\(gearCatch.id).name",
                labelKey: "catchRecord.checkYourAnswers.label.gear",
                value: gear.name,
                changeRoute: measurementsRoute,
                gearName: gear.name
            )
        ]

        for measurement in gear.requiredMeasurements {
            guard let value = measurement.value else { continue }
            rows.append(
                Row(
                    id: "gear.\(gearCatch.id).measurement.\(measurement.id)",
                    labelKey: measurement.labelKey,
                    value: String(value),
                    changeRoute: measurementsRoute,
                    gearName: gear.name
                )
            )
        }

        for measurement in gear.variableMeasurements {
            guard let value = measurement.value else { continue }
            rows.append(
                Row(
                    id: "gear.\(gearCatch.id).variableMeasurement.\(measurement.id)",
                    labelKey: measurement.labelKey,
                    value: String(value),
                    changeRoute: selectGearRoute,
                    gearName: gear.name
                )
            )
        }

        if let statisticalArea = gearCatch.statisticalArea {
            rows.append(
                Row(
                    id: "gear.\(gearCatch.id).statisticalArea",
                    labelKey: "catchRecord.checkYourAnswers.label.statisticalArea",
                    value: statisticalArea,
                    changeRoute: locationRoute,
                    gearName: gear.name,
                    resumesAtCheckYourAnswers: true
                )
            )
        }

        rows.append(
            contentsOf: gearCatch.speciesCaught.flatMap {
                weightRows(
                    for: $0,
                    idPrefix: "gear.\(gearCatch.id).speciesCaught.\($0.id)",
                    aboveLabelKey: "catchRecord.checkYourAnswers.label.weightAbove",
                    changeRoute: speciesRoute,
                    gearName: gear.name,
                    resumesAtCheckYourAnswers: true
                )
            }
        )

        return rows
    }

    // MARK: - Species not landed

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
        changeRoute: CatchRecordRoute,
        gearName: String? = nil,
        resumesAtCheckYourAnswers: Bool = false
    ) -> [Row] {
        var rows: [Row] = [
            Row(
                id: "\(idPrefix).name",
                labelKey: "catchRecord.checkYourAnswers.label.speciesName",
                value: species.name,
                changeRoute: changeRoute,
                gearName: gearName,
                resumesAtCheckYourAnswers: resumesAtCheckYourAnswers
            )
        ]

        if !species.weightAboveMinimumKg.isEmpty {
            rows.append(
                Row(
                    id: "\(idPrefix).above",
                    labelKey: aboveLabelKey,
                    value: "\(species.weightAboveMinimumKg) kg",
                    changeRoute: changeRoute,
                    gearName: gearName,
                    resumesAtCheckYourAnswers: resumesAtCheckYourAnswers
                )
            )
        }

        if let below = species.weightBelowMinimumKg, !below.isEmpty {
            rows.append(
                Row(
                    id: "\(idPrefix).below",
                    labelKey: "catchRecord.checkYourAnswers.label.weightBelow",
                    value: "\(below) kg",
                    changeRoute: changeRoute,
                    gearName: gearName,
                    resumesAtCheckYourAnswers: resumesAtCheckYourAnswers
                )
            )
        }

        if let discarded = species.weightLegallyDiscardedKg, !discarded.isEmpty {
            rows.append(
                Row(
                    id: "\(idPrefix).discarded",
                    labelKey: "catchRecord.checkYourAnswers.label.weightDiscarded",
                    value: "\(discarded) kg",
                    changeRoute: changeRoute,
                    gearName: gearName,
                    resumesAtCheckYourAnswers: resumesAtCheckYourAnswers
                )
            )
        }

        return rows
    }
}
