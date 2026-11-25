import Foundation

/// Errors mapping a locally-held `CatchRecordDraftPayload` into the Catch Recording Service's
/// `CompleteReplacementPayload` wire shape (see ADR-0025/ADR-0028). Every case is a **permanent**
/// failure — nothing here is a transient network condition, so `CatchRecordSubmissionCoordinator`
/// never retries a mapping failure automatically; the record falls back to showing as **Draft**
/// (AC7) and the error is logged for diagnostics (never the record's content — see security
/// instructions).
nonisolated enum CatchRecordMappingError: Error, Equatable, Sendable {
    case missingVessel
    /// The vessel is known, but no RSS (Registry of Shipping and Seamen) number is held for it —
    /// see `VesselOption.rssNumber`. Thrown whenever the selected vessel's registration number is
    /// missing from the downloaded reference data (see ADR-0025/ADR-0028).
    case missingVesselDetails
    case missingTripDates
    case missingPorts
    case missingGear
    case missingStatisticalArea(gearID: String)

    /// A machine-readable diagnostic code (never free text) for `CatchRecordDraftStoring.
    /// markSubmissionFailed(localID:permanent:errorCode:)`.
    var errorCode: String {
        switch self {
        case .missingVessel: return "mapping_missing_vessel"
        case .missingVesselDetails: return "mapping_missing_vessel_details"
        case .missingTripDates: return "mapping_missing_trip_dates"
        case .missingPorts: return "mapping_missing_ports"
        case .missingGear: return "mapping_missing_gear"
        case .missingStatisticalArea: return "mapping_missing_statistical_area"
        }
    }
}

/// Converts the device's own `CatchRecordDraftPayload` into the Catch Recording Service's
/// `CompleteReplacementPayload` (see ADR-0025 §4 "Complete replacement"), so
/// `CatchRecordSubmissionCoordinator` can submit a locally-completed catch record for real.
///
/// Pure, free-standing `enum` (no stored state) so the mapping is trivially unit-testable in
/// isolation from any networking/persistence concern — mirrors `CatchRecordRouting`/
/// `RecordsMerging`.
///
/// **Known simplification** (flagged, not hidden — see ADR-0028 "Known simplifications"): the
/// Catch Recording Service's schema expects a statistical-area *id*, *code* and *name* triple, but
/// the device currently only ever captures a statistical area **code** (no id/name reference-data
/// lookup exists yet for it — see ADR-0025 §7 "Open questions"). Until a real statistical-area
/// reference source exists, this mapper synthesises the id/name fields from what is actually held
/// on-device (the area code) rather than blocking every submission on reference data that doesn't
/// exist yet.
nonisolated enum CatchRecordPayloadMapper {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// - Parameter vessel: the resolved vessel for this draft — already looked up (by snapshot or
    ///   by name) by the caller (see `CatchRecordSubmissionCoordinator`), since resolving it is an
    ///   `async` operation this otherwise-pure mapper should not need to perform itself.
    static func map(
        payload: CatchRecordDraftPayload,
        vessel: VesselOption?
    ) throws -> CompleteReplacementPayload {
        guard payload.vessel != nil else { throw CatchRecordMappingError.missingVessel }
        guard let vessel, let rssNumber = vessel.rssNumber else {
            throw CatchRecordMappingError.missingVesselDetails
        }
        guard let departureDate = payload.departureDate, let returnDate = payload.returnDate else {
            throw CatchRecordMappingError.missingTripDates
        }
        guard let departurePort = payload.departurePort, let returnPort = payload.returnPort else {
            throw CatchRecordMappingError.missingPorts
        }
        guard !payload.gearCatches.isEmpty else { throw CatchRecordMappingError.missingGear }

        let vesselSnapshot = VesselSnapshotDTO(
            id: vessel.id,
            rssSnapshot: rssNumber,
            nameSnapshot: vessel.name,
            externalMarkSnapshot: vessel.externalMark ?? rssNumber,
            lengthOverallMetresSnapshot: vessel.lengthOverallMetres
        )

        let trip = TripDTO(
            startedAndFinishedToday: Calendar.current.isDate(departureDate, inSameDayAs: returnDate),
            dateStarted: dateFormatter.string(from: departureDate),
            dateEnded: dateFormatter.string(from: returnDate),
            departurePort: portDTO(for: departurePort),
            returnPort: portDTO(for: returnPort)
        )

        let gears = try payload.gearCatches.map(gearAssociation(for:))

        return CompleteReplacementPayload(
            vessel: vesselSnapshot,
            trip: trip,
            pairFishing: PairFishingDTO(enabled: false),
            gears: gears,
            speciesNotLanded: payload.speciesNotLanded.map(speciesWeightEntry(for:))
        )
    }

    private static func portDTO(for port: PortOption) -> CatchRecordPortDTO {
        CatchRecordPortDTO(id: port.id, codeSnapshot: port.code ?? port.id, nameSnapshot: port.name)
    }

    private static func gearAssociation(for gearCatch: GearCatch) throws -> GearAssociationDTO {
        guard let statisticalArea = gearCatch.statisticalArea else {
            throw CatchRecordMappingError.missingStatisticalArea(gearID: gearCatch.gear.id)
        }
        let gear = gearCatch.gear
        let characteristics = (gear.requiredMeasurements + gear.variableMeasurements).compactMap { measurement -> CharacteristicDTO? in
            guard let value = measurement.value else { return nil }
            return CharacteristicDTO(
                characteristicId: measurement.apiCode ?? measurement.id,
                nameSnapshot: measurement.id,
                value: .number(Double(value))
            )
        }
        return GearAssociationDTO(
            associationId: gear.id,
            gear: GearSnapshotDTO(id: gear.id, codeSnapshot: gear.referenceId ?? gear.id, nameSnapshot: gear.name),
            characteristics: characteristics,
            statisticalArea: StatisticalAreaDTO(id: statisticalArea, codeSnapshot: statisticalArea, nameSnapshot: statisticalArea),
            speciesCaught: gearCatch.speciesCaught.map(speciesWeightEntry(for:))
        )
    }

    private static func speciesWeightEntry(for species: SpeciesOption) -> SpeciesWeightEntryDTO {
        SpeciesWeightEntryDTO(
            id: species.id,
            faoCodeSnapshot: species.faoCode ?? species.id,
            nameSnapshot: species.name,
            weightAboveMinimumKg: Double(species.weightAboveMinimumKg),
            weightBelowMinimumKg: species.weightBelowMinimumKg.flatMap(Double.init),
            weightLegallyDiscardedKg: species.weightLegallyDiscardedKg.flatMap(Double.init)
        )
    }
}
