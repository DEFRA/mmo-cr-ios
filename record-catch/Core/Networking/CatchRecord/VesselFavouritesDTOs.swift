//
//  VesselFavouritesDTOs.swift
//  record-catch
//
//  Wire-shaped request/response types for the Catch Recording Service's vessel favourites routes
//  (`/v1/vessels/{vesselId}/favourite-{gears,species,ports}`) — see
//  docs/api/catch-recording-service-openapi.yaml and ADR-0025.
//

import Foundation

nonisolated struct FavouriteGearsResponseDTO: Codable, Equatable, Sendable {
    let vesselId: String
    let favouriteGearIds: [String]
}

nonisolated struct FavouriteSpeciesResponseDTO: Codable, Equatable, Sendable {
    let vesselId: String
    let favouriteSpeciesIds: [String]
}

nonisolated struct FavouritePortsResponseDTO: Codable, Equatable, Sendable {
    let vesselId: String
    let favouritePortIds: [String]
}

nonisolated struct FavouriteGearPayload: Codable, Equatable, Sendable {
    let gearId: String
}

nonisolated struct FavouriteSpeciesPayload: Codable, Equatable, Sendable {
    let speciesId: String
}

nonisolated struct FavouritePortPayload: Codable, Equatable, Sendable {
    let portId: String
}
