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
    var lat: Double
    var lng: Double
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.lat = 0.0
        self.lng = 0.0
        
    }
    
    
//    func register(username: String, password: String) async throws {
//        let response: AuthResponseDTO = try await apiClient.send(try .register(username: username, password: password))
//        try applyAuthResponse(response)
//    }
    func location(lat: Double, lng: Double, radius: Int, time: Date) async throws -> Array<FoundLocationsDTO> {
        let response: Array<FoundLocationsDTO>  = try await apiClient.send(try .findRestaurants(lat: lat, lng: lng, radius: radius, time: time))
        self.lat = lat
        self.lng = lng
        return response
    }
    
    func restaurantInfo(restaurant_id: String) async throws -> RestaurantDTO {
        let response: RestaurantDTO  = try await apiClient.send(.restaurantDetails(restaurant: restaurant_id, lat: lat, lng: lng))
        return response
    }
    
    func visited(placeId: String) async throws{
        return try await apiClient.send(Endpoint.visitedRestaurant(placeId: placeId))
    }
    
    func showVisited() async throws -> Array<VisitedRestaurantDTO>{
        let restaurants: Array<VisitedRestaurantDTO> = try await apiClient.send(Endpoint.showVisited())
        return restaurants
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
