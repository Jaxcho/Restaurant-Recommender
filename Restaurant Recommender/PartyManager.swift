//
//  PartyManager.swift
//  Restaurant Recommender
//
//  The party the user is in right now. Every call stores the server's latest
//  copy in `party`, so the lobby just reads it.
//

import Foundation

@Observable
@MainActor
final class PartyManager {

    let apiClient: APIClient
    private(set) var party: PartyDTO?

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func create(lat: Double, lng: Double, radius: Double) async throws {
        party = try await apiClient.send(try .createParty(lat: lat, lng: lng, radius: radius), as: PartyDTO.self)
    }

    func join(code: String) async throws {
        party = try await apiClient.send(try .joinParty(code: code), as: PartyDTO.self)
    }

    /// Loads the party the user is still in on the server, so it survives logging out and back in.
    func restore() async throws {
        let before = party?.code
        let current = try await apiClient.send(.currentParty(), as: PartyDTO?.self)
        // Skip if create, join or leave changed the party while this was loading
        guard party?.code == before else { return }
        party = current
    }

    /// Re-fetches the party so new members and the host's picks show up.
    func refresh() async throws {
        guard let code = party?.code else { return }
        let latest = try await apiClient.send(.party(code: code), as: PartyDTO.self)
        // Skip if the user left while this was loading, or if it's an older
        // "waiting" reply arriving after pick() already stored the picks
        guard party?.code == code, !(party?.status == "picked" && latest.status == "waiting") else { return }
        party = latest
    }

    /// Host only: the server picks restaurants for the whole party.
    func pick() async throws {
        guard let code = party?.code else { return }
        party = try await apiClient.send(.pickParty(code: code), as: PartyDTO.self)
    }

    /// Leaves on the server too. When the host leaves, the party ends for everyone.
    func leave() async throws {
        guard let code = party?.code else { return }
        try await apiClient.send(.leaveParty(code: code))
        party = nil
    }

    /// Forgets the party on this phone only (used on logout); the server still has it.
    func reset() {
        party = nil
    }
}
