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
    @State private var hasLoaded: Bool = false

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

    func loadPlaces() async {
        errorMessage = nil
        do {
            places = try await functionManager.wantToGo()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load your saved places."
        }
        hasLoaded = true
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
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't open that restaurant."
            }
        }
    }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    errorBanner(errorMessage)
                }
                .listRowBackground(Color.red.opacity(0.12))
            }

            Section {
                ForEach(places) { place in
                    placeRow(place)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .overlay {
            if !hasLoaded {
                ProgressView()
            } else if places.isEmpty && errorMessage == nil {
                ContentUnavailableView(
                    "No saved spots yet",
                    systemImage: "bookmark",
                    description: Text("Tap Want to Go on any restaurant to save it here.")
                )
            }
        }
        .navigationTitle("Want to Go")
        .refreshable {
            await loadPlaces()
        }
        .task {
            await loadPlaces()
        }
        // The sheet can remove the place from the list, so reload when it closes.
        .sheet(isPresented: $showModal, onDismiss: {
            Task {
                await loadPlaces()
            }
        }) {
            ModalContentView(location: location, hours: hours, restaurantName: restaurantName, placeId: selectedPlaceId, distance: distance, showVisited: false, userReviews: userReviews, restaurantReview: restaurantReview, photoUrl: photoUrl, cuisine: places.first { $0.placeId == selectedPlaceId }?.cuisine)
        }
    }

    private func placeRow(_ place: WantToGoDTO) -> some View {
        Button {
            selectedPlaceId = place.placeId
            restaurantData(restaurant_id: place.placeId, restaurant_name: place.name)
        } label: {
            HStack(spacing: 12) {
                CuisineBadge(cuisine: place.cuisine)
                VStack(alignment: .leading, spacing: 2) {
                    // Concrete colors: inside a list button, .primary would mean the orange tint
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    if let cuisine = place.cuisine {
                        Text(CuisineStyle.of(cuisine).label)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }
                Spacer(minLength: 8)
                if isSubmitting && selectedPlaceId == place.placeId {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(isSubmitting)
        .swipeActions {
            Button(role: .destructive) {
                remove(place)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
        .font(.callout)
    }
}
