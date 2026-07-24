//
//  DTOs.swift
//  Simple Todo App
//
//  Wire-format types mirroring the backend's Pydantic schemas. Property names
//  are camelCase; `JSONDecoder.api`/`JSONEncoder.api` convert to/from the
//  backend's snake_case JSON automatically.
//

import Foundation

// MARK: - Responses : Response from BackEnd

nonisolated struct OpeningHoursStruct: Decodable {
    let open: HourStruct?
    let close: HourStruct?
}

nonisolated struct HourStruct: Decodable {
    let day: Int
    let hour: Int
    let minute: Int
}

nonisolated struct UserDTO: Decodable {
//    let id: UUID
    let username: String
}

nonisolated struct TokenPairDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
}

nonisolated struct AuthResponseDTO: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
//    let user: UserDTO
}

nonisolated struct FoundLocationsDTO: Decodable, Identifiable {
    let id: String
    let name: String
}

nonisolated struct UserDinedDTO: Encodable {
    let placeId: String
}

nonisolated struct RestaurantDTO: Decodable{
    let reviewSummary: String
    let currentOpeningHours : Array<OpeningHoursStruct>
    let location: Array<Double>
    let distance: Double
}

nonisolated struct VisitedRestaurantDTO: Decodable, Identifiable {
    let placeId: String
    let hours: String
    let location: String
    let id: Int
    let name: String
}

// MARK: - Request payloads : Body of Request


nonisolated struct UsernamePasswordPayload: Encodable {
    let username: String
    let password: String
}

nonisolated struct RefreshTokenPayload: Encodable {
    let refreshToken: String
}

nonisolated struct CoordinatesPayload: Encodable {
    let lat: Double
    let lng: Double
    let radius: Int
    let time : Date
}



