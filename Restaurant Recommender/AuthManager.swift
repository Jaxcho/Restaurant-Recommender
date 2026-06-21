//
//  AuthManager.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/14/26.
//

import Foundation

@Observable
@MainActor

final class AuthManager{
    enum State{
        case loggedOut
        case loggedIn
    }
    private(set) var state: State = .loggedOut
    private(set) var isBootstrapping: Bool
    
    let apiClient: APIClient
    private let tokenStore: TokenStore
    
    var isAuthenticated: Bool { state == State.loggedIn }
    
    init(apiClient: APIClient, tokenStore: TokenStore = TokenStore()) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.isBootstrapping = tokenStore.refreshToken != nil
        
        let client = apiClient
        Task {[weak self] in
            await client.setSessionExpiredHandler {
                Task { @MainActor in self?.state = .loggedOut }
            }
            await self?.bootstrap()
        }
    }
    
    private func bootstrap() async {
        defer { isBootstrapping = false }
        guard tokenStore.refreshToken != nil else { return }
        do {
            let _: UserDTO = try await apiClient.send(.me)
            state =  .loggedIn
        } catch {
            state = .loggedOut
        }
    }
    
    func register(username: String, password: String) async throws {
        let response: AuthResponseDTO = try await apiClient.send(try .register(username: username, password: password))
        try applyAuthResponse(response)
    }
    func login(username: String, password: String) async throws {
        let response: AuthResponseDTO = try await apiClient.send(try .login(username: username, password: password))
        try applyAuthResponse(response)
    }
    
    func logout() async {
        if let refreshToken = tokenStore.refreshToken, let endpoint = try? Endpoint.logout(refreshToken: refreshToken) {
            try? await apiClient.send(endpoint)
        }
        tokenStore.clear();
        state = .loggedOut
    }
    
    
    private func applyAuthResponse(_ response: AuthResponseDTO) throws {
        try tokenStore.save(accessToken: response.accessToken, refreshToken: response.refreshToken)
        state = .loggedIn
    }
}
