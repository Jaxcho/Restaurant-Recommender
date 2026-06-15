//
//  DTOs.swift
//  Simple Todo App
//
//  Wire-format types mirroring the backend's Pydantic schemas. Property names
//  are camelCase; `JSONDecoder.api`/`JSONEncoder.api` convert to/from the
//  backend's snake_case JSON automatically.
//

import Foundation

// MARK: - Responses

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


// MARK: - Request payloads

nonisolated struct UsernamePasswordPayload: Encodable {
    let username: String
    let password: String
}

nonisolated struct RefreshTokenPayload: Encodable {
    let refreshToken: String
}
