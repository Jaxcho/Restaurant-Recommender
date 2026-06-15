//
//  APIClient.swift
//  Simple Todo App
//

import Foundation

/// Talks to the backend, attaching the access token and transparently
/// refreshing it on a 401.
///
/// Implemented as an actor so concurrent requests that all hit a 401 share a
/// single in-flight refresh (`refreshTask`) instead of each racing to rotate
/// the refresh token — racing would cause every request but the first to hit
/// the server's reuse-detection and get its whole session family revoked.
actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenStore: TokenStore

    private var refreshTask: Task<Void, Error>?
    private var sessionExpiredHandler: (@Sendable () -> Void)?

    init(baseURL: URL, tokenStore: TokenStore = TokenStore(), session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    /// Invoked when the refresh token itself turns out to be invalid/expired
    /// — i.e. the user must sign in again. Set by `AuthManager` so it can
    /// drop back to the logged-out state from anywhere in the app.
    func setSessionExpiredHandler(_ handler: @escaping @Sendable () -> Void) {
        sessionExpiredHandler = handler
    }

    // MARK: - High-level requests

    @discardableResult
    func send<Response: Decodable>(_ endpoint: Endpoint, as type: Response.Type = Response.self) async throws -> Response {
        let data = try await execute(endpoint, allowRefresh: true)
        do {
            return try JSONDecoder.api.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    func send(_ endpoint: Endpoint) async throws {
        _ = try await execute(endpoint, allowRefresh: true)
    }

    // MARK: - Core execution

    private func execute(_ endpoint: Endpoint, allowRefresh: Bool) async throws -> Data {
        let request = try buildRequest(for: endpoint)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401 where endpoint.requiresAuth && allowRefresh:
            try await refreshTokens()
            return try await execute(endpoint, allowRefresh: false)
        case 406:
            throw APIError.userNameTaken
        default:
            throw APIError.server(status: http.statusCode, message: serverMessage(from: data))
        }
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        request.httpMethod = endpoint.method.rawValue

        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if endpoint.requiresAuth {
            guard let accessToken = tokenStore.accessToken else {
                throw APIError.notAuthenticated
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func serverMessage(from data: Data) -> String? {
        try? JSONDecoder().decode(ServerErrorEnvelope.self, from: data).detail
    }

    // MARK: - Single-flight refresh

    private func refreshTokens() async throws {
        if let inFlight = refreshTask {
            return try await inFlight.value
        }

        let task = Task<Void, Error> {
            try await self.performRefresh()
        }
        refreshTask = task
        defer { refreshTask = nil }

        try await task.value
    }

    private func performRefresh() async throws {
        guard let refreshToken = tokenStore.refreshToken else {
            failSession()
            throw APIError.sessionExpired
        }

        do {
            let endpoint = try Endpoint.refresh(refreshToken: refreshToken)
            let data = try await execute(endpoint, allowRefresh: false)
            let pair = try JSONDecoder.api.decode(TokenPairDTO.self, from: data)
            try tokenStore.save(accessToken: pair.accessToken, refreshToken: pair.refreshToken)
        } catch {
            failSession()
            throw APIError.sessionExpired
        }
    }

    private func failSession() {
        tokenStore.clear()
        sessionExpiredHandler?()
    }
}
