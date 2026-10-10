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
    @State private var hasLoaded: Bool = false
    @State private var locations: Array<VisitedRestaurantDTO> = []
    @State private var distance: Double = 0.0
    @State private var restaurantReview: String = ""
    @State private var restaurantName: String = ""
    @State private var showModal: Bool = false
    @State private var selectedPlaceId: String = ""
    @State private var userReviews: Array<RestaurantReviewsDTO> = []
    @State private var photoUrl: String?

    func searchRestaurants() {

    }

    func loadVisited() async {
        errorMessage = nil
        do {
            locations = try await functionManager.showVisited()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load your visits."
        }
        hasLoaded = true
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
                ForEach(locations) { visited in
                    visitedRow(visited)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .overlay {
            if !hasLoaded {
                ProgressView()
            } else if locations.isEmpty && errorMessage == nil {
                ContentUnavailableView(
                    "No visits yet",
                    systemImage: "checkmark.seal",
                    description: Text("Tap Mark Visited on any restaurant and it'll show up here.")
                )
            }
        }
        .navigationTitle("Visited")
        .refreshable {
            await loadVisited()
        }
        .task {
            await loadVisited()
        }
        .sheet(isPresented: $showModal) {
            ModalContentView(location: location, hours: hours,  restaurantName: restaurantName, placeId: selectedPlaceId, distance: distance, showVisited: true, userReviews: userReviews, restaurantReview: restaurantReview, photoUrl: photoUrl, cuisine: locations.first { $0.placeId == selectedPlaceId }?.cuisine)
        }
    }

    private func visitedRow(_ visited: VisitedRestaurantDTO) -> some View {
        Button {
            selectedPlaceId = visited.placeId
            restaurantData(restaurant_id: visited.placeId, restaurant_name: visited.name)
        } label: {
            HStack(spacing: 12) {
                CuisineBadge(cuisine: visited.cuisine)
                VStack(alignment: .leading, spacing: 4) {
                    // Concrete colors: inside a list button, .primary would mean the orange tint
                    Text(visited.name)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(visitDatesText(visited.datesVisited))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                    if visited.datesVisited.count > 1 {
                        TagLabel(text: "Visited \(visited.datesVisited.count)×", systemImage: "repeat")
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Visited \(visited.datesVisited.count) times")
                    }
                }
                Spacer(minLength: 8)
                if isSubmitting && selectedPlaceId == visited.placeId {
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
    }

    private func visitDatesText(_ apiDates: [String]) -> String {
        if apiDates.isEmpty {
            return "Date not recorded"
        }
        // "yyyy-MM-dd" strings sort in date order, so this puts the newest visit first
        let newestFirst = apiDates.sorted(by: >)
        return newestFirst.map { prettyDate($0) }.joined(separator: " · ")
    }

    private func prettyDate(_ apiDate: String) -> String {
        guard let date = APIDateCoding.dateOnly.date(from: apiDate) else {
            return apiDate
        }
        if Calendar.current.isDate(date, equalTo: .now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
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
