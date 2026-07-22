//
//  FunctionManager.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/30/26.
//

//
//  AuthManager.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/14/26.
//

import Foundation

@Observable
@MainActor

final class FunctionManager{

    let apiClient: APIClient
    
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
        
    }
    
    
//    func register(username: String, password: String) async throws {
//        let response: AuthResponseDTO = try await apiClient.send(try .register(username: username, password: password))
//        try applyAuthResponse(response)
//    }
    func location(lat: Double, lng: Double, radius: Int, time: Date) async throws -> Array<FoundLocationsDTO> {
        let response: Array<FoundLocationsDTO>  = try await apiClient.send(try .findRestaurants(lat: lat, lng: lng, radius: radius, time: time))
        return response
    }
    
    func restaurantInfo(restaurant_id: String) async throws -> RestaurantDTO {
        let response: RestaurantDTO  = try await apiClient.send(try .restaurantDetails(restaurant: restaurant_id))
        return response
    }
    
    func visited(placeId: String) async throws{
        try await apiClient.send(Endpoint.visitedRestaurant(placeId: placeId))
    }
//
//    func location() async {
//        if let refreshToken = tokenStore.refreshToken, let endpoint = try? Endpoint.logout(refreshToken: refreshToken) {
//            try? await apiClient.send(endpoint)
//        }
//        tokenStore.clear();
//        state = .loggedOut
//    }
    
//    
//    private func applyAuthResponse(_ response: AuthResponseDTO) throws {
//        try tokenStore.save(accessToken: response.accessToken, refreshToken: response.refreshToken)
//        state = .loggedIn
//    }
}
