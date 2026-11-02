//
//  CatchRecordDTOs.swift
//  record-catch
//
//  Wire-shaped request/response types for the catch-record submission API — see
//  CatchRecordEndpoint.swift/CatchRecordService.swift.
//
//  ⚠️ Placeholder shapes: the real MMO backend contract for this route is not yet confirmed (see
//  CatchRecordEndpoint.swift's placeholder-route warning). `CatchRecordSubmissionRequestDTO` is a
//  best-effort, field-for-field copy of `CatchRecordDraftPayload` (see
//  Features/Common/Data/CatchRecordDraft.swift) — the full in-progress journey's domain snapshot —
//  kept as the connector's **own** `Codable` type rather than a passthrough of that domain model
//  (mirrors how `VesselDTO`/`SpeciesDTO`/`PortDTO` are kept separate from
//  `VesselOption`/`SpeciesOption`/`PortOption`, see ADR-0018), so this wire shape can be corrected
//  independently once the real contract is known, without touching the journey's own domain types.
//  Expect this DTO (and the response below) to change once the backend team confirms the actual
//  request/response schema.
//

import Foundation

/// Placeholder request body for `POST {baseURL}/api/v1/catch-records`.
///
/// Deliberately **not** `Equatable`/round-trip tested against `CatchRecordDraftPayload` beyond the
/// `init(payload:)` mapping below — this type exists purely so `CatchRecordService` has something
/// concrete to encode and test against ahead of the real contract.
nonisolated struct CatchRecordSubmissionRequestDTO: Encodable, Sendable, Equatable {
    let vessel: String?
    let departureDate: Date?
    let returnDate: Date?
    let departurePort: PortOption?
    let returnPort: PortOption?
    let gearCatches: [GearCatch]
    let speciesNotLanded: [SpeciesOption]

    /// Builds the placeholder wire request directly from the in-progress journey's domain draft
    /// (see `CatchRecordDraftPayload`) — a 1:1 field copy for now, since the real backend's exact
    /// request contract isn't confirmed yet (see the file-level doc comment above). This mapping —
    /// and the fields it copies — is very unlikely to survive unchanged once the real schema lands.
    init(payload: CatchRecordDraftPayload) {
        self.vessel = payload.vessel
        self.departureDate = payload.departureDate
        self.returnDate = payload.returnDate
        self.departurePort = payload.departurePort
        self.returnPort = payload.returnPort
        self.gearCatches = payload.gearCatches
        self.speciesNotLanded = payload.speciesNotLanded
    }
}

/// Placeholder response body for a successful submission.
///
/// `referenceNumber` matches the existing UI-facing concept already threaded through
/// `CatchRecordSubmissionServicing`/`CheckYourAnswersViewModel` (see
/// Features/Common/Data/CatchRecordSubmissionService.swift) — the real backend's actual field
/// name/shape for this is unconfirmed.
nonisolated struct CatchRecordSubmissionResponseDTO: Decodable, Sendable, Equatable {
    let referenceNumber: String
}
