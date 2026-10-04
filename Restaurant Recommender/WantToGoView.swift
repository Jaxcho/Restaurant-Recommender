//
//  WantToGoView.swift
//  Restaurant Recommender
//

import SwiftUI

/// Restaurants the user saved to try later. Same layout as ShowVisited.
struct WantToGoView: View {
    @Environment(FunctionManager.self) private var functionManager
    @State private var places: Array<WantToGoDTO> = []
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false

    // Details for the sheet
    @State private var showModal: Bool = false
    @State private var selectedPlaceId: String = ""
    @State private var restaurantName: String = ""
    @State private var restaurantReview: String = ""
    @State private var location: Array<Double> = []
    @State private var hours: Array<OpeningHoursStruct> = []
    @State private var distance: Double = 0
    @State private var userReviews: Array<RestaurantReviewsDTO> = []
    @State private var photoUrl: String?

    func loadPlaces() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                places = try await functionManager.wantToGo()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Uh oh"
            }
        }
    }

    func remove(_ place: WantToGoDTO) {
        errorMessage = nil
        Task {
            do {
                try await functionManager.removeWantToGo(placeId: place.placeId)
                places.removeAll { $0.placeId == place.placeId }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't remove it."
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
                userReviews = try await functionManager.getReviews(restaurant_id: restaurant_id)
                distance = restaurant.distance
                restaurantReview = restaurant.reviewSummary
                photoUrl = restaurant.photoUrl
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

            List(places) { place in
                Button {
                    selectedPlaceId = place.placeId
                    restaurantData(restaurant_id: place.placeId, restaurant_name: place.name)
                } label: {
                    HStack {
                        Text(place.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isSubmitting)
                .swipeActions {
                    Button("Remove", role: .destructive) {
                        remove(place)
                    }
                }
            }
            .overlay {
                if places.isEmpty {
                    ContentUnavailableView(
                        "Nothing saved yet",
                        systemImage: "bookmark",
                        description: Text("Tap Want to Go on a restaurant to save it here.")
                    )
                }
            }
        }
        .navigationTitle("Want to Go")
        .onAppear {
            loadPlaces()
        }
        // The sheet can remove the place from the list, so reload when it closes.
        .sheet(isPresented: $showModal, onDismiss: loadPlaces) {
            ModalContentView(location: location, hours: hours, restaurantName: restaurantName, placeId: selectedPlaceId, distance: distance, showVisited: false, userReviews: userReviews, restaurantReview: restaurantReview, photoUrl: photoUrl)
        }
    }
}
