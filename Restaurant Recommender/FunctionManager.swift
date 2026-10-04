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
    func location(lat: Double, lng: Double, radius: Double, time: Date) async throws -> Array<FoundLocationsDTO> {
        let response: Array<FoundLocationsDTO>  = try await apiClient.send(try .findRestaurants(lat: lat, lng: lng, radius: radius, time: time))
        self.lat = lat
        self.lng = lng
        return response
    }
    
    func restaurantInfo(restaurant_id: String) async throws -> RestaurantDTO {
        let response: RestaurantDTO  = try await apiClient.send(.restaurantDetails(restaurant: restaurant_id, lat: lat, lng: lng))
        return response
    }
    func visited(placeId: String, dateVisited: Date) async throws {
        let formatted = APIDateCoding.dateOnly.string(from: dateVisited)
        try await apiClient.send(Endpoint.visitedRestaurant(placeId: placeId, dateVisited: formatted))
    }
    
    func showVisited() async throws -> Array<VisitedRestaurantDTO>{
        let restaurants: Array<VisitedRestaurantDTO> = try await apiClient.send(Endpoint.showVisited())
        return restaurants
    }
    
    func pickLocation(address: String, radius: Double) async throws -> PickLocationDTO {
        let response: PickLocationDTO = try await apiClient.send(.pickRestaurant(address: address, radius: radius))
        self.lat = response.lat
        self.lng = response.lng
        return response
    }
    
    func autocomplete(text: String) async throws -> Array<AutocompleteDTO> {
        return try await apiClient.send(.autocomplete(text: text))
    }

    func getReviews(restaurant_id: String) async throws -> Array<RestaurantReviewsDTO>{
        return try await apiClient.send(.getReviews(restaurant_id: restaurant_id))
    }
    
    func postReview(placeId: String, rating: Double, content: String) async throws -> RestaurantReviewsDTO{
        let newReview: RestaurantReviewsDTO = try await apiClient.send(.postReview(placeId: placeId, rating:rating, content: content))
        return newReview
    }
    
    func getHours(placeId: String) async throws -> HoursDTO {
        let response: HoursDTO = try await apiClient.send(.hours(placeId: placeId))
        return response
    }
    
    // Sends the phone's local time, since restaurant hours are local too.
    // Calendar counts Sunday as 1; the API wants 0 = Sunday.
    func recommendations(placeIds: [String], lat: Double, lng: Double, date: Date) async throws -> Array<RecommendationsDTO> {
        let calendar = Calendar.current
        let day = calendar.component(.weekday, from: date) - 1
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return try await apiClient.send(try .recommend(placeIds: placeIds, lat: lat, lng: lng, day: day, hour: hour, minute: minute))
    }

    func triedPlaceIds() async throws -> Set<String> {
        let placeIds: Array<String> = try await apiClient.send(.triedRestaurants())
        return Set(placeIds)
    }

    func cuisines() async throws -> Array<CuisineDTO> {
        return try await apiClient.send(.cuisines())
    }

    // cuisine key -> score (-1, 0, 1). Empty means onboarding was never done.
    func preferences() async throws -> [String: Int] {
        let response: PreferencesDTO = try await apiClient.send(.preferences())
        var scores: [String: Int] = [:]
        for taste in response.tastes {
            scores[taste.key] = taste.score
        }
        return scores
    }

    // Sends every key in `order`; anything missing from `scores` is sent as 0 (neutral).
    func savePreferences(scores: [String: Int], order: Array<String>) async throws {
        let tastes = order.map { TasteDTO(key: $0, score: scores[$0] ?? 0) }
        try await apiClient.send(try .savePreferences(tastes: tastes))
    }

    func wantToGo() async throws -> Array<WantToGoDTO> {
        return try await apiClient.send(.wantToGo())
    }

    func addWantToGo(placeId: String) async throws {
        try await apiClient.send(try .addWantToGo(placeId: placeId))
    }

    func removeWantToGo(placeId: String) async throws {
        try await apiClient.send(.removeWantToGo(placeId: placeId))
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
