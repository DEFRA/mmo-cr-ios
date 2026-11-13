//
//  CatchRecordDTOs.swift
//  record-catch
//
//  Wire-shaped request/response types for the Catch Recording Service (catch-record lifecycle +
//  vessel favourites API), built from the service's own OpenAPI 3.1 spec — see
//  docs/api/catch-recording-service-openapi.yaml and ADR-0025.
//
//  Kept as this connector's **own** `Codable` types rather than reusing any domain model (mirrors
//  how `VesselDTO`/`SpeciesDTO`/`PortDTO` are kept separate from
//  `VesselOption`/`SpeciesOption`/`PortOption` — ADR-0018), so the wire shape can evolve
//  independently of the "Create a catch record" journey's own domain types. **Not yet wired** to
//  any screen or the local draft store — see `CatchRecordServicesFactory`/ADR-0025 for scope.
//

import Foundation

// MARK: - Shared enums

nonisolated enum PersistedCatchRecordStatus: String, Codable, Sendable {
    case draft = "DRAFT"
    case submitted = "SUBMITTED"
    case complete = "COMPLETE"
}

nonisolated enum DisplayCatchRecordStatus: String, Codable, Sendable {
    case draft = "Draft"
    case amended = "Amended"
    case submitted = "Submitted"
    case complete = "Complete"
}

nonisolated enum CatchRecordArtifactType: String, Codable, Sendable {
    case json
    case pdf
}

nonisolated enum CatchRecordArtifactKind: String, Codable, Sendable {
    case jsonSnapshot = "JSON_SNAPSHOT"
    case pdfReceipt = "PDF_RECEIPT"
}

/// The four canonical section names `PATCH`/`PUT` operate on (see `SectionPatchPayload`).
nonisolated enum CatchRecordSection: String, Codable, Sendable {
    case trip
    case pairFishing
    case gears
    case speciesNotLanded
}

// MARK: - Shared value objects

nonisolated struct CatchRecordPortDTO: Codable, Equatable, Sendable {
    let id: String
    let codeSnapshot: String
    let nameSnapshot: String
}

nonisolated struct VesselSnapshotDTO: Codable, Equatable, Sendable {
    let id: String
    let rssSnapshot: String
    let nameSnapshot: String
    let externalMarkSnapshot: String
    let lengthOverallMetresSnapshot: Double?
}

/// `dateStarted`/`dateEnded` are modelled as plain `String`, not `Date` — the spec declares them as
/// bare `{ type: string }` with no `format: date-time`, and their exact shape (date-only vs
/// date-time) is not yet confirmed (see ADR-0025 "Open questions").
nonisolated struct TripDTO: Codable, Equatable, Sendable {
    let startedAndFinishedToday: Bool
    let dateStarted: String
    let dateEnded: String
    let departurePort: CatchRecordPortDTO
    let returnPort: CatchRecordPortDTO
}

/// `pairVessel`/`pairSkipperName` are **required and nullable** in the service's schema — a custom
/// `encode(to:)` is needed because Swift's synthesised `Encodable` conformance omits a `nil`
/// `Optional` key entirely rather than writing an explicit JSON `null`, and this service's schema
/// requires the key to always be present (see ADR-0025 "Explicit null encoding").
nonisolated struct PairFishingDTO: Codable, Equatable, Sendable {
    let enabled: Bool
    let pairVessel: String?
    let pairSkipperName: String?

    init(enabled: Bool, pairVessel: String? = nil, pairSkipperName: String? = nil) {
        self.enabled = enabled
        self.pairVessel = pairVessel
        self.pairSkipperName = pairSkipperName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(pairVessel, forKey: .pairVessel)
        try container.encode(pairSkipperName, forKey: .pairSkipperName)
    }
}

/// A characteristic's value can be a number, a string, or a boolean (the spec's `oneOf`) — this
/// mirrors that shape exactly rather than collapsing it to `String`, so a caller/test can inspect
/// which underlying JSON type the service actually sent.
nonisolated enum CharacteristicValue: Codable, Equatable, Sendable {
    case number(Double)
    case string(String)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let numberValue = try? container.decode(Double.self) {
            self = .number(numberValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                CharacteristicValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected a number, string, or bool")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }
}

nonisolated struct CharacteristicDTO: Codable, Equatable, Sendable {
    let characteristicId: String
    let nameSnapshot: String
    let value: CharacteristicValue
    let unitSnapshot: String?

    init(characteristicId: String, nameSnapshot: String, value: CharacteristicValue, unitSnapshot: String? = nil) {
        self.characteristicId = characteristicId
        self.nameSnapshot = nameSnapshot
        self.value = value
        self.unitSnapshot = unitSnapshot
    }
}

nonisolated struct StatisticalAreaDTO: Codable, Equatable, Sendable {
    let id: String
    let codeSnapshot: String
    let nameSnapshot: String
}

nonisolated enum CatchRecordWeightPrecision: String, Codable, Sendable {
    case wholeNumber
    case oneDecimalPlace
}

/// Shared shape for both a gear's `speciesCaught` entries and the root `speciesNotLanded` entries.
/// The weight fields are optional (not required by the service's schema) so they are left out of
/// the encoded JSON entirely when `nil`, rather than needing the explicit-`null` treatment
/// `PairFishingDTO` requires for its required-and-nullable fields.
nonisolated struct SpeciesWeightEntryDTO: Codable, Equatable, Sendable {
    let id: String
    let faoCodeSnapshot: String
    let nameSnapshot: String
    let weightAboveMinimumKg: Double?
    let weightBelowMinimumKg: Double?
    let weightLegallyDiscardedKg: Double?
    let weightPrecision: CatchRecordWeightPrecision?

    init(
        id: String,
        faoCodeSnapshot: String,
        nameSnapshot: String,
        weightAboveMinimumKg: Double? = nil,
        weightBelowMinimumKg: Double? = nil,
        weightLegallyDiscardedKg: Double? = nil,
        weightPrecision: CatchRecordWeightPrecision? = nil
    ) {
        self.id = id
        self.faoCodeSnapshot = faoCodeSnapshot
        self.nameSnapshot = nameSnapshot
        self.weightAboveMinimumKg = weightAboveMinimumKg
        self.weightBelowMinimumKg = weightBelowMinimumKg
        self.weightLegallyDiscardedKg = weightLegallyDiscardedKg
        self.weightPrecision = weightPrecision
    }
}

nonisolated struct GearSnapshotDTO: Codable, Equatable, Sendable {
    let id: String
    let codeSnapshot: String
    let nameSnapshot: String
}

/// One gear occurrence — the authoritative root for its characteristics, statistical area, and
/// landed species.
nonisolated struct GearAssociationDTO: Codable, Equatable, Sendable {
    let associationId: String
    let gear: GearSnapshotDTO
    let characteristics: [CharacteristicDTO]
    let statisticalArea: StatisticalAreaDTO?
    let speciesCaught: [SpeciesWeightEntryDTO]

    init(
        associationId: String,
        gear: GearSnapshotDTO,
        characteristics: [CharacteristicDTO] = [],
        statisticalArea: StatisticalAreaDTO? = nil,
        speciesCaught: [SpeciesWeightEntryDTO] = []
    ) {
        self.associationId = associationId
        self.gear = gear
        self.characteristics = characteristics
        self.statisticalArea = statisticalArea
        self.speciesCaught = speciesCaught
    }
}

nonisolated struct ArtifactMetadataDTO: Codable, Equatable, Sendable {
    let submissionNumber: Int
    let type: CatchRecordArtifactKind
}

// MARK: - Canonical Catch Record Object v1

/// The authoritative Canonical Catch Record Object v1 — the current mutable operational record, as
/// returned (embedded or standalone) by `GET /v1/catch-records/{catchRecordId}`.
nonisolated struct CatchRecordDTO: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: String
    let catchRecordReference: String
    let ownerUserId: String
    let status: PersistedCatchRecordStatus
    let version: Int
    let numberOfSubmissions: Int
    let hasUnsubmittedChanges: Bool
    let vessel: VesselSnapshotDTO
    let trip: TripDTO
    let pairFishing: PairFishingDTO
    let gears: [GearAssociationDTO]
    let speciesNotLanded: [SpeciesWeightEntryDTO]
    let artifacts: [ArtifactMetadataDTO]
    let createdAt: Date
    let createdBy: String
    let updatedAt: Date
    let updatedBy: String
    let submittedAt: Date?
    let submittedBy: String?
    let completedAt: Date?
    let completedBy: String?
}

// MARK: - Progress / section completion (shared by several responses)

nonisolated struct SectionCompletionDTO: Codable, Equatable, Sendable {
    let trip: Bool
    let pairFishing: Bool
    let gears: Bool
}

nonisolated struct CatchRecordProgressDTO: Codable, Equatable, Sendable {
    let hasUnsubmittedChanges: Bool
    let numberOfSubmissions: Int
    let incompleteGearAssociationIds: [String]
    let currentIncompleteGearAssociationId: String?
    let allGearsComplete: Bool
}

// MARK: - Save / submission responses

/// Common response shape for every save-style operation (create draft, replace, section save,
/// abandon's non-204 sibling calls, edit-start).
nonisolated struct StandardSaveResponseDTO: Codable, Equatable, Sendable {
    let id: String
    let catchRecordReference: String
    let status: PersistedCatchRecordStatus
    let displayStatus: DisplayCatchRecordStatus
    let version: Int
    /// The canonical section name just saved, or `nil` for first draft creation.
    let savedSection: CatchRecordSection?
    let sectionCompletion: SectionCompletionDTO
    let progress: CatchRecordProgressDTO
}

/// `SubmissionResponse` in the spec is `StandardSaveResponse` plus three extra required fields on
/// the same JSON object (an `allOf` with no further nesting) — decoded by reading the base
/// response from the same container, then the extra keys, rather than nesting a sub-object.
nonisolated struct SubmissionResponseDTO: Codable, Equatable, Sendable {
    let standard: StandardSaveResponseDTO
    let submittedAt: Date
    let submittedBy: String
    let artifacts: [ArtifactMetadataDTO]

    private enum ExtraCodingKeys: String, CodingKey {
        case submittedAt
        case submittedBy
        case artifacts
    }

    init(from decoder: Decoder) throws {
        standard = try StandardSaveResponseDTO(from: decoder)
        let container = try decoder.container(keyedBy: ExtraCodingKeys.self)
        submittedAt = try container.decode(Date.self, forKey: .submittedAt)
        submittedBy = try container.decode(String.self, forKey: .submittedBy)
        artifacts = try container.decode([ArtifactMetadataDTO].self, forKey: .artifacts)
    }

    func encode(to encoder: Encoder) throws {
        try standard.encode(to: encoder)
        var container = encoder.container(keyedBy: ExtraCodingKeys.self)
        try container.encode(submittedAt, forKey: .submittedAt)
        try container.encode(submittedBy, forKey: .submittedBy)
        try container.encode(artifacts, forKey: .artifacts)
    }
}

// MARK: - Retrieve

/// `RetrieveCatchRecordResponse` is `CatchRecord` plus six extra required fields on the same JSON
/// object (another same-object `allOf`) — same decoding approach as `SubmissionResponseDTO` above.
nonisolated struct RetrieveCatchRecordResponseDTO: Codable, Equatable, Sendable {
    let record: CatchRecordDTO
    let displayStatus: DisplayCatchRecordStatus
    let sectionCompletion: SectionCompletionDTO
    let completedSections: [CatchRecordSection]
    let incompleteSections: [CatchRecordSection]
    let progress: CatchRecordProgressDTO
    /// Preliminary eligibility fact only — a `true` value is not itself proof a submission will be
    /// accepted (see the spec's own caveat).
    let submissionEligible: Bool

    private enum ExtraCodingKeys: String, CodingKey {
        case displayStatus
        case sectionCompletion
        case completedSections
        case incompleteSections
        case progress
        case submissionEligible
    }

    init(from decoder: Decoder) throws {
        record = try CatchRecordDTO(from: decoder)
        let container = try decoder.container(keyedBy: ExtraCodingKeys.self)
        displayStatus = try container.decode(DisplayCatchRecordStatus.self, forKey: .displayStatus)
        sectionCompletion = try container.decode(SectionCompletionDTO.self, forKey: .sectionCompletion)
        completedSections = try container.decode([CatchRecordSection].self, forKey: .completedSections)
        incompleteSections = try container.decode([CatchRecordSection].self, forKey: .incompleteSections)
        progress = try container.decode(CatchRecordProgressDTO.self, forKey: .progress)
        submissionEligible = try container.decode(Bool.self, forKey: .submissionEligible)
    }

    func encode(to encoder: Encoder) throws {
        try record.encode(to: encoder)
        var container = encoder.container(keyedBy: ExtraCodingKeys.self)
        try container.encode(displayStatus, forKey: .displayStatus)
        try container.encode(sectionCompletion, forKey: .sectionCompletion)
        try container.encode(completedSections, forKey: .completedSections)
        try container.encode(incompleteSections, forKey: .incompleteSections)
        try container.encode(progress, forKey: .progress)
        try container.encode(submissionEligible, forKey: .submissionEligible)
    }
}

// MARK: - Listing

nonisolated struct CatchRecordListingVesselDTO: Codable, Equatable, Sendable {
    let nameSnapshot: String?
    let rssSnapshot: String?
}

nonisolated struct CatchRecordListingTripDTO: Codable, Equatable, Sendable {
    let dateStarted: String?
    let dateEnded: String?
}

nonisolated struct CatchRecordListingProgressDTO: Codable, Equatable, Sendable {
    let allGearsComplete: Bool?
}

nonisolated struct CatchRecordListingItemDTO: Codable, Equatable, Sendable {
    let id: String
    let catchRecordReference: String
    let status: PersistedCatchRecordStatus
    let displayStatus: DisplayCatchRecordStatus
    let version: Int
    let vessel: CatchRecordListingVesselDTO
    let trip: CatchRecordListingTripDTO
    let createdAt: Date
    let updatedAt: Date
    let submittedAt: Date?
    let completedAt: Date?
    let progress: CatchRecordListingProgressDTO
}

nonisolated struct CatchRecordListResponseDTO: Codable, Equatable, Sendable {
    let items: [CatchRecordListingItemDTO]
    let limit: Int
    let count: Int
}

// MARK: - History

nonisolated struct CatchRecordHistoryEventDTO: Codable, Equatable, Sendable {
    let id: String
    let eventType: String
    let timestamp: Date
    let actor: String
    let section: String?
    let submissionNumber: Int?
}

nonisolated struct CatchRecordHistoryResponseDTO: Codable, Equatable, Sendable {
    let catchRecordId: String
    let status: PersistedCatchRecordStatus
    let displayStatus: DisplayCatchRecordStatus
    let version: Int
    let hasUnsubmittedChanges: Bool
    let numberOfSubmissions: Int
    let events: [CatchRecordHistoryEventDTO]
}

// MARK: - Submissions list (metadata only — no artifact download, see ADR-0025 scope)

nonisolated struct SubmissionArtifactSummaryDTO: Codable, Equatable, Sendable {
    let type: CatchRecordArtifactType
    let contentType: String
    let contentLength: Int
    let checksum: String
}

nonisolated struct SubmissionGroupDTO: Codable, Equatable, Sendable {
    let submissionNumber: Int
    let artifacts: [SubmissionArtifactSummaryDTO]
}

nonisolated struct SubmissionsListResponseDTO: Codable, Equatable, Sendable {
    let catchRecordId: String
    let count: Int
    let submissions: [SubmissionGroupDTO]
}

// MARK: - Request payloads

/// `POST /v1/catch-records` body.
///
/// ⚠️ `catchRecordReference` is populated from the app's own client-generated reference (see
/// `CatchRecordReferenceGenerator`, ADR-0026) — `{RSS}-{DDMMYYYY}-{HHMMSS}`. This does **not**
/// match the service's currently-documented `^GBR-[A-Z0-9]+-\d{6}-\d{6}$` validation pattern; the
/// service will reject it until the backend team updates that validation (see ADR-0025/ADR-0026
/// "Known dependency"). This connector deliberately does not re-validate against that pattern
/// client-side, so a future backend change to accept the app's format needs no client change.
nonisolated struct CreateDraftCatchRecordPayload: Codable, Equatable, Sendable {
    let vesselId: String
    let catchRecordReference: String?

    init(vesselId: String, catchRecordReference: String? = nil) {
        self.vesselId = vesselId
        self.catchRecordReference = catchRecordReference
    }
}

/// `PATCH /v1/catch-records/{catchRecordId}` body — one of the four canonical sections.
///
/// The spec's `data` field is loosely typed (`oneOf` a generic object or an array of generic
/// objects); this connector models each case with the concrete DTOs already defined above instead,
/// so call sites get type safety while still encoding to the same `{ "section": ..., "data": ... }`
/// wire shape.
nonisolated enum SectionPatchPayload: Equatable, Sendable {
    case trip(TripDTO)
    case pairFishing(PairFishingDTO)
    case gears([GearAssociationDTO])
    case speciesNotLanded([SpeciesWeightEntryDTO])

    var section: CatchRecordSection {
        switch self {
        case .trip: return .trip
        case .pairFishing: return .pairFishing
        case .gears: return .gears
        case .speciesNotLanded: return .speciesNotLanded
        }
    }
}

extension SectionPatchPayload: Encodable {
    private enum CodingKeys: String, CodingKey {
        case section
        case data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(section, forKey: .section)
        switch self {
        case .trip(let trip): try container.encode(trip, forKey: .data)
        case .pairFishing(let pairFishing): try container.encode(pairFishing, forKey: .data)
        case .gears(let gears): try container.encode(gears, forKey: .data)
        case .speciesNotLanded(let species): try container.encode(species, forKey: .data)
        }
    }
}

/// `PUT /v1/catch-records/{catchRecordId}` body — complete mobile replacement of every
/// client-owned section. See `SectionPatchPayload`'s doc comment for why the spec's generic
/// `additionalProperties: true` object shapes are modelled with concrete DTOs here instead.
nonisolated struct CompleteReplacementPayload: Codable, Equatable, Sendable {
    let vessel: VesselSnapshotDTO
    let trip: TripDTO
    let pairFishing: PairFishingDTO
    let gears: [GearAssociationDTO]
    let speciesNotLanded: [SpeciesWeightEntryDTO]
}
