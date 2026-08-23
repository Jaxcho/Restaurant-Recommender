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
        VStack(spacing: 0) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            List(locations) { visited in
                Button {
                    selectedPlaceId = visited.placeId
                    restaurantData(restaurant_id: visited.placeId, restaurant_name: visited.name)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(visited.name)
                                .foregroundStyle(.primary)
                            Text(visited.datesVisited.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isSubmitting)
            }
            .overlay {
                if locations.isEmpty {
                    ContentUnavailableView(
                        "Nothing visited yet",
                        systemImage: "checkmark.circle",
                        description: Text("Restaurants you mark as visited will show up here.")
                    )
                }
            }
        }
        .navigationTitle("Visited")
        .onAppear {
            loadVisited()
        }
        .sheet(isPresented: $showModal) {
            ModalContentView(location: location, hours: hours,  restaurantName: restaurantName, placeId: selectedPlaceId, distance: distance, showVisited: true, restaurantReview: restaurantReview)
        }
    }
}
