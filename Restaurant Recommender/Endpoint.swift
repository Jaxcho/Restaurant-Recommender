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
    
    nonisolated static func findRestaurants(lat: Double, lng: Double, radius: Int, time: Date) throws -> Endpoint {
        Endpoint(
            path: "/find_restaurants",
            method: .post,
            body: try JSONEncoder.api.encode(CoordinatesPayload(lat: lat, lng: lng, radius: radius, time : time)),
            requiresAuth: true
        )
    }
    
    nonisolated static func restaurantDetails(restaurant: String) throws -> Endpoint {
        Endpoint(
            path: "/restaurant_details/\(restaurant)",
            method: .get,
            body: nil,
            requiresAuth: true
        )
    }
    
    nonisolated static func visitedRestaurant(restaurant_id: String, ) throws -> Endpoint {
        Endpoint(
            path: "/visited_restaurants/\(restaurant)",
            method: .post,
            body: nil,
            requiresAuth: true
        )
    }
    
    nonisolated static let me = Endpoint(path: "users/me", method: .get)

}
