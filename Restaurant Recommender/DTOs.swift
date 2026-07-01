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

