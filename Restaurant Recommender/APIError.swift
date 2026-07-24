//
//  APIError.swift
//  Simple Todo App
//

import Foundation

nonisolated enum APIError: Error, LocalizedError {
    case notAuthenticated
    case sessionExpired
    case invalidURL(String)
    case invalidResponse
    case decodingFailed(Error)
    case server(status: Int, message: String?)
    case transport(Error)
    case userNameTaken

    var errorDescription: String? {
        switch self {
        case let .invalidURL(path):
            return "Couldn't build a valid request URL for \(path)."
        case .userNameTaken:
            return "Username is taken, please choose another one."
        case .notAuthenticated:
            return "You need to be signed in to do that."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .invalidResponse:
            return "Received an unexpected response from the server."
        case .decodingFailed:
            return "Couldn't read the server's response."
        case let .server(_, message):
            return message ?? "Something went wrong. Please try again."
        case .transport:
            return "Couldn't connect to the server. Check your connection and try again."
        }
    }
}

/// Mirrors FastAPI's `{"detail": "..."}` error envelope for simple
/// `HTTPException`s (validation errors use a richer array form we don't
/// surface verbatim — the client validates inputs before sending).
nonisolated struct ServerErrorEnvelope: Decodable {
    let detail: String?
}
