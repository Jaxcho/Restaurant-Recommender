//
//  Endpoint.swift
//  Simple Todo App
//

import Foundation

nonisolated struct Endpoint {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    let path: String
    var queryItems: [URLQueryItem]?
    let method: Method
    var body: Data?
    var requiresAuth: Bool = true
}

extension Endpoint {
    // MARK: - Auth

    nonisolated static func register(username: String, password: String) throws -> Endpoint {
        Endpoint(
            path: "auth/register",
            method: .post,
            body: try JSONEncoder.api.encode(UsernamePasswordPayload(username: username, password: password)),
            requiresAuth: false
        )
    }

    nonisolated static func login(username: String, password: String) throws -> Endpoint {
        Endpoint(
            path: "auth/login",
            method: .post,
            body: try JSONEncoder.api.encode(UsernamePasswordPayload(username: username, password: password)),
            requiresAuth: false
        )
    }
//
//    nonisolated static func register(username: String, password: String) throws -> Endpoint {
//        Endpoint(
//            path: "auth/register",
//            method: .post,
//            body: try JSONEncoder.api.encode(UsernamePasswordPayload(username: username, password: password)),
//            requiresAuth: false
//        )
//    }
    
    nonisolated static func refresh(refreshToken: String) throws -> Endpoint {
        Endpoint(
            path: "auth/refresh",
            method: .post,
            body: try JSONEncoder.api.encode(RefreshTokenPayload(refreshToken: refreshToken)),
            requiresAuth: false
        )
    }

    nonisolated static func logout(refreshToken: String) throws -> Endpoint {
        Endpoint(
            path: "auth/logout",
            method: .post,
            body: try JSONEncoder.api.encode(RefreshTokenPayload(refreshToken: refreshToken)),
            requiresAuth: false
        )
    }
    
    nonisolated static func findRestaurants(lat: Double, lng: Double, radius: Double, time: Date) throws -> Endpoint {
        Endpoint(
            path: "/find_restaurants",
            method: .post,
            body: try JSONEncoder.api.encode(CoordinatesPayload(lat: lat, lng: lng, radius: radius, time : time)),
            requiresAuth: true
        )
    }
    
    nonisolated static func restaurantDetails(restaurant: String, lat: Double, lng: Double) -> Endpoint {
        Endpoint(
            path: "restaurant_details/\(restaurant)",
            queryItems: [
                URLQueryItem(name: "lat", value: String(lat)),
                URLQueryItem(name: "lng", value: String(lng))
            ],
            method: .get
        )
    }
    
    nonisolated static func visitedRestaurant(placeId: String, dateVisited: String ) throws -> Endpoint {
        Endpoint(
            path: "/visited_restaurants",
            method: .post,
            body: try JSONEncoder.api.encode(VisitedRestaurantPayload(placeId: placeId, dateVisited:dateVisited)),
            requiresAuth: true
        )
    }
    
    nonisolated static func showVisited() -> Endpoint {
        Endpoint(
            path: "/show_visited",
            method: .get,
            requiresAuth: true
        )
    }
    
    nonisolated static func pickRestaurant(address: String, radius: Double) throws -> Endpoint {
        Endpoint(
            path: "/pick_location",
            method: .post,
            body: try JSONEncoder.api.encode(PickLocationPayload(address: address, radius: radius)),
            requiresAuth: true
        )
    }
    
    nonisolated static func getReviews(restaurant_id: String) throws -> Endpoint {
        Endpoint(
            path: "/get_reviews",
            queryItems: [
                URLQueryItem(name: "restaurant_id", value: String(restaurant_id))
            ],
            method: .get,
            requiresAuth: true
        )
    }
    
    nonisolated static func postReview(placeId: String, rating: Double, content: String) throws -> Endpoint{
        Endpoint(
            path: "/post_review",
            method: .post,
            body: try JSONEncoder.api.encode(RestaurantReviewPayload(placeId: placeId, rating: rating, content: content)),
            requiresAuth: true
        )
    }
    
    nonisolated static let me = Endpoint(path: "users/me", method: .get)

}


