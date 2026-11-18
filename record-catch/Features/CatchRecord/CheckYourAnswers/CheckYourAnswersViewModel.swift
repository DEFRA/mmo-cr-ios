import Foundation

/// View model for the "Check your answers" screen, ending the "Create a catch record" journey.
///
/// Presents every value captured in `CatchRecordDraft` as ordered, read-only sections — Trip, one
/// section **per selected gear** (that gear's details, its statistical area and the species caught
/// with it — see ADR-0011), then Species not landed — each row pairing a label with an
/// already-formatted display value and a `changeRoute` that returns the user to the screen where
/// that value was captured.
///
/// Also owns the submission step itself (the former standalone "Confirmation" screen's behaviour
/// was folded into this screen — see the module README and ADR-0014 amendment): the declaration
/// notice/bullets shown beneath the summary are informational only (there is no separate
/// confirmation checkbox), so "Accept and submit trip details" calls `submit(isOnline:)` directly.
///
/// **Submission queue (ADR-0028):** the record is always enqueued first
/// (`CatchRecordSubmissionQueuing.enqueue(_:)`), *before* any network attempt is made, so it is
/// never lost — even if the app is killed immediately afterwards it stays **Complete/Pending** on
/// Home and is retried automatically once a connection is available. If the device is online, this
/// then tries to send that one record straight away, with a short timeout
/// (`submitNow(localID:timeout:)`):
/// - **Sent and accepted** → `submissionSuccess` (the real green confirmation — only ever shown
///   once the backend has actually accepted the record).
/// - **Still queued** (offline, a retryable failure, or the attempt didn't finish within the
///   timeout) → `submissionSaved` — the truthful "saved on this device, will send automatically"
///   screen (BR-SUB-008/AC10/AC11) — never the green one.
/// - **Failed permanently** (validation/mapping/configuration — nothing a retry would fix) →
///   a recoverable inline error (`submitFailed`), and the record falls back to showing as Draft.
@MainActor
@Observable
final class CheckYourAnswersViewModel {

    /// Display-only placeholder reference number shown at the top of the screen.
    let referenceNumber: String

    private(set) var isSubmitting = false
    /// Set when submission fails **permanently** (never worth retrying automatically — validation,
    /// mapping, configuration), so the view can surface a recoverable, accessible error rather than
    /// silently discarding the attempt.
    private(set) var submitFailed = false

    private let router: CatchRecordRouter
    private let draft: CatchRecordDraft
    private let submissionQueue: CatchRecordSubmissionQueuing

    /// How long `submit(isOnline: true)` waits for the backend to accept the record before
    /// treating it as still-queued rather than blocking the user indefinitely (see ADR-0028).
    static let onlineSubmissionTimeout: TimeInterval = 20

    init(
        referenceNumber: String,
        router: CatchRecordRouter,
        draft: CatchRecordDraft,
        submissionQueue: CatchRecordSubmissionQueuing = StubCatchRecordSubmissionQueue()
    ) {
        self.referenceNumber = referenceNumber
        self.router = router
        self.draft = draft
        self.submissionQueue = submissionQueue
    }

    /// A single labelled fact about the trip, with the route its "Change" link returns to.
    struct Row: Identifiable, Hashable {
        let id: String
        /// String Catalog key for the row's label.
        let labelKey: String
        /// The already-formatted value to display (dates, names and weights are pre-formatted so
        /// the view performs no further formatting logic).
        let value: String
        /// The route this row's "Change" control returns the user to, or `nil` when the field
        /// cannot be changed from here — currently only the vessel: vessel selection is a one-time
        /// first step of the journey and cannot be changed once a record exists (see ADR-0013
        /// amendment), so its row is shown read-only, with no "Change" link rendered at all.
        let changeRoute: CatchRecordRoute?
        /// The gear this row belongs to, when it is part of a per-gear section — `nil` for
        /// trip-level/species-not-landed rows. Used to build a gear-disambiguated accessibility
        /// label for the row's "Change" control, since the same field label (e.g. "Statistical
        /// area") repeats once per gear section (see GOV.UK Design System — Check answers: a
        /// summary-card's Change link must say what it changes).
        var gearName: String?

        init(
            id: String,
            labelKey: String,
            value: String,
            changeRoute: CatchRecordRoute?,
            gearName: String? = nil
        ) {
            self.id = id
            self.labelKey = labelKey
            self.value = value
            self.changeRoute = changeRoute
            self.gearName = gearName
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

    /// Pushes the destination for a row's "Change" control. Every "Change" link returns straight
    /// back to Check your answers once its own onward mini-journey completes, rather than
    /// continuing forward through the rest of the create-a-catch-record journey — see
    /// `CatchRecordDraft.returnToCheckYourAnswers` and ADR-0013 (which generalises the per-gear
    /// pattern first introduced by ADR-0011 to every row).
    func change(to route: CatchRecordRoute) {
        draft.returnToCheckYourAnswers = true
        router.push(route)
    }

    /// Confirms the summary and submits the completed record via the on-device submission queue —
    /// see the class doc comment for the full behaviour.
    ///
    /// - Parameter isOnline: the device's connectivity at the moment "Accept and submit trip
    ///   details" is tapped (see `ConnectivityMonitoring`). Defaults to `true` so every existing
    ///   call site and test exercises the online path unchanged; the view passes the live signal
    ///   explicitly, matching the "nil/unknown treated as online" convention used by
    ///   `OfflineBanner`.
    func submit(isOnline: Bool = true) async {
        // Guards against a double-tap submitting twice while the first attempt is in flight.
        guard !isSubmitting else { return }
        submitFailed = false

        // Always enqueue first, before any network attempt — the record must never be lost, even
        // if the app is killed immediately afterwards (ADR-0028).
        await submissionQueue.enqueue(draft)

        guard isOnline else {
            router.push(.submissionSaved(referenceNumber: referenceNumber))
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let outcome = await submissionQueue.submitNow(localID: draft.localID, timeout: Self.onlineSubmissionTimeout)
        switch outcome {
        case .submitted:
            router.push(.submissionSuccess(referenceNumber: referenceNumber))
        case .queued:
            router.push(.submissionSaved(referenceNumber: referenceNumber))
        case .failedPermanently:
            submitFailed = true
        }
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
                    // No "Change" link: vessel selection is a one-time first step of the journey
                    // and cannot be changed once a record exists (see ADR-0013 amendment).
                    changeRoute: nil
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
        // measurements are captured on the select-gear screen; the statistical area and species
        // caught are captured per gear (ADR-0011) via the catch-location/species screens. Every
        // "Change" returns the user to the screen where that value was entered, then straight back
        // to Check your answers once saved (see ADR-0013).
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
                    gearName: gear.name
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
                    gearName: gear.name
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
        gearName: String? = nil
    ) -> [Row] {
        var rows: [Row] = [
            Row(
                id: "\(idPrefix).name",
                labelKey: "catchRecord.checkYourAnswers.label.speciesName",
                value: species.name,
                changeRoute: changeRoute,
                gearName: gearName
            )
        ]

        if !species.weightAboveMinimumKg.isEmpty {
            rows.append(
                Row(
                    id: "\(idPrefix).above",
                    labelKey: aboveLabelKey,
                    value: "\(species.weightAboveMinimumKg) kg",
                    changeRoute: changeRoute,
                    gearName: gearName
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
                    gearName: gearName
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
                    gearName: gearName
                )
            )
        }

        return rows
    }
}
