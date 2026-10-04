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
    let breakfast: Bool
    let lunch: Bool
    let dinner: Bool
    // Optional: older saved restaurants may not have a location yet
    let lat: Double?
    let lng: Double?
    let distance: Double?        // miles from the search center
    let averageRating: Double?   // nil when nobody has reviewed it
    let reviewCount: Int
    let hours: Array<OpeningHoursStruct>
}

nonisolated struct RestaurantDTO: Decodable{
    let reviewSummary: String
    let currentOpeningHours : Array<OpeningHoursStruct>
    let location: Array<Double>
    let distance: Double
    let photoUrl: String?
}

nonisolated struct PickLocationDTO: Decodable {
    let lat: Double
    let lng: Double
    let restaurants: Array<FoundLocationsDTO>
}

nonisolated struct VisitedRestaurantDTO: Decodable, Identifiable {
    let placeId: String
    let id: Int
    let name: String
    let datesVisited: [String]}

nonisolated struct RestaurantReviewsDTO: Decodable, Identifiable {
    let id: Int
    let restaurantId: Int
    let reviewerName: String
    let reviewerId: String
    let content: String
    let rating: Double
}

nonisolated struct HoursDTO: Decodable {
    let breakfast: Bool
    let lunch: Bool
    let dinner: Bool
}

nonisolated struct AutocompleteDTO: Decodable, Identifiable {
    let placeId: String
    let text: String
    var id: String { placeId }
}

nonisolated struct RecommendationsDTO: Decodable, Identifiable {
    let placeId: String
    let name: String
    let rating: Double  // predicted rating, 1-5
    let reason: String  // e.g. "Liked by 3 people with similar taste"
    let isWildcard: Bool  // a cuisine you haven't tried that people with your taste love
    var id: String { placeId }
}

nonisolated struct CuisineDTO: Decodable, Identifiable {
    let key: String
    let label: String
    var id: String { key }
}

// One cuisine score: -1 = not for me, 0 = neutral, 1 = love it.
// Sent as an array (not a dictionary) so convertFromSnakeCase can't rename keys like "fast_food".
nonisolated struct TasteDTO: Codable, Hashable {
    let key: String
    let score: Int
}

nonisolated struct PreferencesDTO: Decodable {
    let tastes: Array<TasteDTO>
}

nonisolated struct WantToGoDTO: Decodable, Identifiable {
    let placeId: String
    let name: String
    var id: String { placeId }
}

nonisolated struct PartyRecommendationDTO: Decodable {
    let placeId: String
    let rating: Double
}


// MARK: - Request payloads : Body of Request

nonisolated struct RestaurantReviewPayload: Encodable {
    let placeId: String
    let rating: Double
    let content: String
}

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
    let radius: Double
    let time : Date
}

nonisolated struct VisitedRestaurantPayload: Encodable {
    let placeId: String
    let dateVisited: String
}

nonisolated struct PickLocationPayload: Encodable {
    let address: String
    let radius: Double
}

nonisolated struct AutocompletePayload: Encodable {
    let text: String
}

nonisolated struct HoursPayload: Encodable {
    let placeId: String
    
}

nonisolated struct RecommendationsPayload: Encodable {
    let placeIds: [String]
    // Search center, used to rank closer places higher
    let lat: Double
    let lng: Double
    // Phone's local time; day is 0 = Sunday like Google's hours
    let day: Int
    let hour: Int
    let minute: Int
}

nonisolated struct PreferencesPayload: Encodable {
    let tastes: Array<TasteDTO>
}

nonisolated struct WantToGoPayload: Encodable {
    let placeId: String
}

nonisolated struct PartyRecommendationPayload: Encodable {
    let users: [String]
    let restaurants: [String]
}
