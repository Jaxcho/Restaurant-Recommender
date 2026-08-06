//
//  ShowVisited.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 7/23/26.
//

import SwiftUI


struct ShowVisited: View {
    @Environment(FunctionManager.self) private var functionManager
    @State private var location: Array<Double> = []
    @State private var hours: Array<OpeningHoursStruct> = []
    @State private var errorMessage: String? = nil
    @State private var isSubmitting: Bool = false
    @State private var locations: Array<VisitedRestaurantDTO> = []
    @State private var distance: Double = 0.0
    @State private var restaurantReview: String = ""
    @State private var restaurantName: String = ""
    @State private var showModal: Bool = false
    @State private var selectedPlaceId: String = ""

    func loadVisited() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                locations = try await functionManager.showVisited()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Uh oh"
            }
        }
    }

    func restaurantData(restaurant_id: String, restaurant_name: String) {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                let restaurant = try await functionManager.restaurantInfo(restaurant_id: restaurant_id)
                distance = restaurant.distance
                restaurantReview = restaurant.reviewSummary
                restaurantName = restaurant_name
                hours = restaurant.currentOpeningHours
                location = restaurant.location
                showModal = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Uh oh"
            }
        }
    }

    var body: some View {
        Text("Locations")
            .onAppear {
                loadVisited()
            }

        if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        }

        List(locations) { visited in
            HStack {
                Text(visited.name)
                Spacer()
                Text(visited.datesVisited.joined(separator: ", "))
                    .foregroundStyle(.secondary)
                Button(">") {
                    selectedPlaceId = visited.placeId
                    restaurantData(restaurant_id: visited.placeId, restaurant_name: visited.name)
                }
                .disabled(isSubmitting)
            }
        }
        .padding()
        .sheet(isPresented: $showModal) {
            ModalContentView(location: location, hours: hours, restaurantReview: restaurantReview, restaurantName: restaurantName, placeId: selectedPlaceId, distance: distance, showVisited: true)
        }
    }
}
