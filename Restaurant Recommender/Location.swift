//
//  Location.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI
import CoreLocation
import MapKit

@Observable
@MainActor

final class LocationModel: NSObject, CLLocationManagerDelegate {


    private(set) var lastKnownLocation: CLLocationCoordinate2D?
    private let manager = CLLocationManager()
    // Callers waiting for the next location fix; resumed in the delegate callbacks.
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    /// Returns the current location, waiting for a fix if one isn't available yet.
    /// Returns nil if access is denied/restricted or the fix fails.
    func currentLocation() async -> CLLocationCoordinate2D? {
        checkLocationAuthorization()

        switch manager.authorizationStatus {
        case .denied, .restricted:
            return nil
        default:
            break
        }

        if let location = lastKnownLocation {
            return location
        }

        // A second caller replaces the first; resume the old one so it never hangs.
        locationContinuation?.resume(returning: nil)
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
        }
    }

    func checkLocationAuthorization() {

        manager.delegate = self

        switch manager.authorizationStatus {
        case .notDetermined://The user choose allow or denny your app to get the location yet
            manager.requestWhenInUseAuthorization()

        case .restricted://The user cannot change this app’s status, possibly due to active restrictions such as parental controls being in place.
            print("Location restricted")
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil

        case .denied://The user dennied your app to get location or disabled the services location or the phone is in airplane mode
            print("Location denied")
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil

        case .authorizedAlways://This authorization allows you to use all location services and receive location events whether or not your app is in use.
            print("Location authorizedAlways")
            manager.requestLocation()

        case .authorizedWhenInUse://This authorization allows you to use all location services and receive location events only when your app is in use
            print("Location authorized when in use")
            lastKnownLocation = manager.location?.coordinate
            manager.requestLocation()

        @unknown default:
            print("Location service disabled")

        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {//Trigged every time authorization status changes
        checkLocationAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastKnownLocation = locations.first?.coordinate
        locationContinuation?.resume(returning: lastKnownLocation)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location failed: \(error.localizedDescription)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
}

// MARK: - Shared pieces

/// A soft red banner for errors on the Discover screen and the details sheet.
private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Brand.closed)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Brand.closed.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A bold section title with a brand-colored icon and an optional caption under it.
private struct SectionHeader: View {
    let title: String
    let systemImage: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(Brand.accent)
            }
            .font(.title3.bold())

            if let caption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Today's status from Google's weekly opening periods (day 0 = Sunday), like
/// "Open · until 9:00 PM" or "Closed · opens Tue 11:00 AM". Nil when the hours are unknown.
private func openStatus(for periods: [OpeningHoursStruct], at date: Date = Date()) -> (isOpen: Bool, text: String)? {
    let calendar = Calendar.current
    let minutesPerWeek = 7 * 24 * 60
    let today = calendar.component(.weekday, from: date) - 1
    let now = today * 24 * 60 + calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)

    var soonestWait = Int.max
    var nextOpening: HourStruct?
    for period in periods {
        guard let open = period.open else { continue }
        guard let close = period.close else { return (true, "Open 24 hours") }
        let start = open.day * 24 * 60 + open.hour * 60 + open.minute
        var end = close.day * 24 * 60 + close.hour * 60 + close.minute
        if end <= start { end += minutesPerWeek }
        if end - start >= minutesPerWeek { return (true, "Open 24 hours") }
        if (start..<end).contains(now) || (start..<end).contains(now + minutesPerWeek) {
            return (true, "Open · until \(clockText(close))")
        }
        let wait = ((start - now) % minutesPerWeek + minutesPerWeek) % minutesPerWeek
        if wait < soonestWait {
            soonestWait = wait
            nextOpening = open
        }
    }

    guard let nextOpening else { return periods.isEmpty ? nil : (false, "Closed") }
    let symbols = calendar.shortWeekdaySymbols
    let opensToday = nextOpening.day == today && soonestWait < 24 * 60
    let day = (opensToday || !symbols.indices.contains(nextOpening.day)) ? "" : symbols[nextOpening.day] + " "
    return (false, "Closed · opens \(day)\(clockText(nextOpening))")
}

private func clockText(_ time: HourStruct) -> String {
    let date = Calendar.current.date(from: DateComponents(hour: time.hour, minute: time.minute)) ?? Date()
    return date.formatted(date: .omitted, time: .shortened)
}

// MARK: - Details sheet

struct ModalContentView: View {

    let location: Array<Double>
    let hours: Array<OpeningHoursStruct>
    let restaurantName: String
    let placeId: String
    let distance: Double
    let showVisited: Bool
    @State var userReviews: Array<RestaurantReviewsDTO>
    let restaurantReview: String
    var photoUrl: String? = nil
    var cuisine: String? = nil
    @State private var rating: Double = 0
    @State private var isWantToGo: Bool = false
    @State private var errorMessage: String?
    @State private var userRestaurantReview: String = ""
    @State private var dateVisited: Date = Date()
    @State private var isSubmittingReview: Bool = false
    @State private var isMarkingVisited: Bool = false
    // Bumped after every successful save so the success haptic plays
    @State private var successCount: Int = 0

    @Environment(FunctionManager.self) private var functionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var style: CuisineStyle { CuisineStyle.of(cuisine) }

    /// Apple Maps directions, when we know where the restaurant is.
    private var directionsURL: URL? {
        guard location.count == 2 else { return nil }
        return URL(string: "http://maps.apple.com/?daddr=\(location[0]),\(location[1])")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero

                header

                actions

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                summaryCard

                writeReviewCard

                if !userReviews.isEmpty {
                    reviewsSection
                }

                if !showVisited {
                    markVisitedCard
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: successCount)
        .task {
            // Is this place already on the user's Want to Go list?
            isWantToGo = (try? await functionManager.wantToGo().contains { $0.placeId == placeId }) ?? false
        }
    }

    /// Adds or removes the place from Want to Go. Flips the button right away,
    /// and flips it back if the request fails.
    private func toggleWantToGo() {
        errorMessage = nil
        isWantToGo.toggle()
        let shouldSave = isWantToGo
        Task {
            do {
                if shouldSave {
                    try await functionManager.addWantToGo(placeId: placeId)
                } else {
                    try await functionManager.removeWantToGo(placeId: placeId)
                }
                successCount += 1
            } catch {
                isWantToGo = !shouldSave
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't update Want to Go."
            }
        }
    }

    private func submitReview() {
        errorMessage = nil
        isSubmittingReview = true
        Task {
            defer { isSubmittingReview = false }
            do {
                let newReview = try await functionManager.postReview(placeId: placeId, rating: rating, content: userRestaurantReview)
                userReviews.append(newReview)
                successCount += 1
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't post your review. Try again."
            }
        }
    }

    private func markVisited() {
        errorMessage = nil
        isMarkingVisited = true
        Task {
            defer { isMarkingVisited = false }
            do {
                try await functionManager.visited(placeId: placeId, dateVisited: dateVisited)
                successCount += 1
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't mark as visited."
            }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        Group {
            if let photoUrl, let url = URL(string: photoUrl) {
                Color.clear
                    .frame(height: 200)
                    .overlay {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                    }
                    .background(style.tint.opacity(0.15))
            } else {
                // No photo: the cuisine's emoji on a soft tinted panel
                Text(style.emoji)
                    .font(.system(size: 72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(style.tint.opacity(0.15))
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityHidden(true)
        .overlay(alignment: .topTrailing) {
            closeButton
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Close")
        .padding(10)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(restaurantName)
                .font(.title2.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if cuisine != nil {
                        TagLabel(text: "\(style.emoji) \(style.label)", tint: style.tint)
                    }
                    // A 0,0 search center gives huge bogus distances, so only show believable ones
                    if !showVisited, distance > 0, distance < 100 {
                        TagLabel(text: "\(distance.formatted(.number.precision(.fractionLength(1)))) mi away", systemImage: "location.fill", tint: Brand.accent)
                    }
                    if let status = openStatus(for: hours) {
                        TagLabel(text: status.text, systemImage: "clock.fill", tint: status.isOpen ? Brand.open : Brand.closed)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                toggleWantToGo()
            } label: {
                Label(isWantToGo ? "Saved" : "Want to Go", systemImage: isWantToGo ? "bookmark.fill" : "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(isWantToGo ? "Remove from Want to Go" : "Add to Want to Go")

            if let directionsURL {
                Button {
                    openURL(directionsURL)
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .font(.headline)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What people say", systemImage: "text.quote")
                .font(.headline)

            if restaurantReview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No review summary yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text(restaurantReview)
                Text("Summary by Google")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var writeReviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Rate it", systemImage: "square.and.pencil")
                .font(.headline)

            StarRatingPicker(rating: $rating)

            TextField("What did you think? (optional)", text: $userRestaurantReview, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                submitReview()
            } label: {
                HStack(spacing: 8) {
                    if isSubmittingReview {
                        ProgressView()
                    }
                    Text(isSubmittingReview ? "Posting…" : "Post Review")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(isSubmittingReview || rating == 0)
        }
        .cardStyle()
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reviews", systemImage: "person.2.fill")
                .font(.headline)

            ForEach(userReviews) { review in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(review.reviewerName.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Brand.accent.gradient, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(review.reviewerName)
                                .font(.subheadline.bold())
                            Spacer()
                            StarRatingView(rating: review.rating)
                        }
                        if !review.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(review.content)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if review.id != userReviews.last?.id {
                    Divider()
                }
            }
        }
        .cardStyle()
    }

    private var markVisitedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Been here?", systemImage: "checkmark.seal")
                .font(.headline)

            DatePicker("Date visited", selection: $dateVisited, in: ...Date(), displayedComponents: .date)

            Button {
                markVisited()
            } label: {
                HStack(spacing: 8) {
                    if isMarkingVisited {
                        ProgressView()
                    }
                    Text(isMarkingVisited ? "Saving…" : "Mark as Visited")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(isMarkingVisited)
        }
        .cardStyle()
    }
}

/// A tappable 5-star input used when writing a review.
struct StarRatingPicker: View {
    @Binding var rating: Double

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = Double(star)
                } label: {
                    Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(Double(star) <= rating ? Brand.star : Color.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(star == 1 ? "1 star" : "\(star) stars")
                .accessibilityAddTraits(Double(star) == rating ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
    }
}

/// A read-only 5-star display for showing an existing review's rating.
struct StarRatingView: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: Double(star) <= rating ? "star.fill" : "star")
            }
        }
        .font(.caption)
        .foregroundStyle(Brand.star)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rating.formatted(.number.precision(.fractionLength(0...1)))) out of 5 stars")
    }
}

/// The three meal windows a restaurant can be open for. Raw values match the
/// backend's `breakfast`/`lunch`/`dinner` flags on `FoundLocationsDTO`.
enum Meal: String, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .breakfast: "sunrise"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        }
    }

    func isAvailable(in location: FoundLocationsDTO) -> Bool {
        switch self {
        case .breakfast: location.breakfast
        case .lunch: location.lunch
        case .dinner: location.dinner
        }
    }
}

extension FoundLocationsDTO {
    /// Whether any opening period covers `date`, using the device's time zone.
    /// Google numbers days 0 = Sunday; `Calendar` uses 1 = Sunday.
    func isOpen(at date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return false }

        let minutesPerWeek = 7 * 24 * 60
        let now = (weekday - 1) * 24 * 60 + hour * 60 + minute

        return hours.contains { period in
            guard let open = period.open else { return false }
            guard let close = period.close else { return true }  // no close time = open 24 hours
            let start = open.day * 24 * 60 + open.hour * 60 + open.minute
            var end = close.day * 24 * 60 + close.hour * 60 + close.minute
            if end <= start { end += minutesPerWeek }  // e.g. opens Saturday night, closes Sunday
            // Check `now` and `now + 1 week` so periods that wrap past Saturday still match
            return (start..<end).contains(now) || (start..<end).contains(now + minutesPerWeek)
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case bestMatch = "Best Match"
    case distance = "Distance"
    case rating = "Rating"

    var id: String { rawValue }
}

// MARK: - Discover screen pieces

/// A restaurant in the results list: cuisine emoji, name, and a one-line summary.
private struct RestaurantRow: View {
    let location: FoundLocationsDTO

    var body: some View {
        HStack(spacing: 14) {
            CuisineBadge(cuisine: location.cuisine)

            VStack(alignment: .leading, spacing: 3) {
                Text(location.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                details
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            mealIcons

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// "★ 4.2 (12) · 0.8 mi · Open"; parts with no data are left out.
    private var details: Text {
        var parts: [Text] = []
        if let averageRating = location.averageRating {
            parts.append(Text(Image(systemName: "star.fill")).foregroundStyle(Brand.star) + Text(" \(averageRating, specifier: "%.1f") (\(location.reviewCount))"))
        }
        if let distance = location.distance {
            parts.append(Text("\(distance, specifier: "%.1f") mi"))
        }
        if !location.hours.isEmpty {
            let isOpen = location.isOpen(at: Date())
            parts.append(Text(isOpen ? "Open" : "Closed").foregroundStyle(isOpen ? Brand.open : Brand.closed))
        }
        guard let first = parts.first else { return Text("No details yet") }
        return parts.dropFirst().reduce(first) { $0 + Text(" · ") + $1 }
    }

    private var mealIcons: some View {
        HStack(spacing: 4) {
            ForEach(Meal.allCases) { meal in
                if meal.isAvailable(in: location) {
                    Image(systemName: meal.icon)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(servesText)
    }

    private var servesText: String {
        let meals = Meal.allCases.filter { $0.isAvailable(in: location) }.map(\.label)
        return meals.isEmpty ? "" : "Serves " + meals.joined(separator: ", ")
    }
}

/// One "Picked for You" card: cuisine, predicted score, and why it was picked.
private struct RecommendationCard: View {
    let recommendation: RecommendationsDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                CuisineBadge(cuisine: recommendation.cuisine, size: 44)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Brand.star)
                        Text(recommendation.rating, format: .number.precision(.fractionLength(1)))
                    }
                    .font(.title3.bold())
                    Text("for you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(recommendation.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(recommendation.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if recommendation.isWildcard {
                TagLabel(text: "Wildcard", systemImage: "sparkles", tint: Brand.wildcard)
            }
        }
        .padding(14)
        .frame(width: 236, alignment: .topLeading)
        .frame(minHeight: 190, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if recommendation.isWildcard {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Brand.wildcard.opacity(0.45), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Discover screen

struct LocationView: View {
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    // Where the map is looking right now, so the zoom buttons can zoom from there
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var locationManager = LocationModel()
    @Environment(FunctionManager.self) private var functionManager
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var errorMessage: String?
    @State private var radius: Double = 1.0
    @State private var time: Date = Date()
    @State private var isSubmitting: Bool = false
    @State private var locations: Array<FoundLocationsDTO> = []
    @State private var restaurantReview: String = ""
    @State private var showModal = false
    @State private var location: Array<Double> = []
    @State private var hours: Array<OpeningHoursStruct> = []
    @State private var restaurantName: String = ""
    @State private var distance: Double = 0
    @State private var address: String = ""
    @State private var userReviews: Array<RestaurantReviewsDTO> = []

    @State private var selectedPlaceId: String = "" // This is the current restaurant id that the modal uses that is used in mark visited
    @State private var selectedCuisine: String?

    @State private var selectedMeals: Set<Meal> = []
    @State private var suggestions: Array<AutocompleteDTO> = []
    // The in-flight debounce task; each keystroke cancels the previous one.
    @State private var autocompleteTask: Task<Void, Never>?
    // Set when we programmatically fill `address` from a suggestion, so the
    // resulting onChange doesn't kick off another autocomplete fetch.
    @State private var isSelectingSuggestion: Bool = false

    @State private var recommendations: Array<RecommendationsDTO> = []
    // Place ids the user has visited or reviewed, for the "New" filter.
    @State private var triedPlaceIds: Set<String> = []
    @State private var showNewOnly: Bool = false
    @State private var showOpenNow: Bool = false
    @State private var sortOption: SortOption = .bestMatch
    // The pin tapped on the map; opens that restaurant's details.
    @State private var selectedPin: String?
    @State private var photoUrl: String?

    // Google rejects searches wider than about 31 miles
    private let radiusOptions: [Double] = [0.5, 1, 2, 5, 10, 25]


    /// The list after filters (meals, New, Open Now) and the chosen sort.
    private var displayedLocations: [FoundLocationsDTO] {
        let now = Date()
        let filtered = locations.filter { location in
            selectedMeals.allSatisfy { $0.isAvailable(in: location) }
                && (!showNewOnly || !triedPlaceIds.contains(location.id))
                && (!showOpenNow || location.isOpen(at: now))
        }
        switch sortOption {
        case .bestMatch:
            return filtered  // Google's order
        case .distance:
            // Places with no known distance go last
            return filtered.sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
        case .rating:
            return filtered.sorted { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }
        }
    }

    /// Fills the search bar with a suggestion and searches for it.
    func selectSuggestion(_ suggestion: AutocompleteDTO) {
        autocompleteTask?.cancel()
        isSelectingSuggestion = true
        address = suggestion.text
        suggestions = []
        pickLocation(address: suggestion.text, radius: radius)
    }

    /// Searches the typed address, or the user's current location when the search box is empty.
    func findFood() {
        if !address.trimmingCharacters(in: .whitespaces).isEmpty {
            pickLocation(address: address, radius: radius)
        } else {
            Task {
                if let coordinate = await locationManager.currentLocation() {
                    latitude = coordinate.latitude
                    longitude = coordinate.longitude
                    time = Date()
                    center(on: coordinate)
                    sendLocation(latitude, longitude, radius, time)
                } else {
                    errorMessage = "Couldn't get your location. Allow location access or search an address."
                }
            }
        }
    }

    func sendLocation(_ latitude: Double, _ longitude: Double ,_ radius: Double, _ time: Date){
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                locations = try await functionManager.location(lat: latitude, lng: longitude, radius: radius, time: time)
                recommendations = []  // old picks don't match the new results
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load restaurants near you."
            }
        }
    }


    func pickLocation(address: String, radius: Double){
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                let response = try await functionManager.pickLocation(address: address, radius: radius)
                locations = response.restaurants
                recommendations = []
                latitude = response.lat
                longitude = response.lng
                center(on: CLLocationCoordinate2D(latitude: response.lat, longitude: response.lng))
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't search that address."
            }
        }
    }

    func restaurantData(restaurant_id: String, restaurant_name: String){
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
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't open this restaurant."
            }
        }
    }

    private func open(placeId: String, name: String, cuisine: String?) {
        selectedPlaceId = placeId
        selectedCuisine = cuisine
        restaurantData(restaurant_id: placeId, restaurant_name: name)
    }


    /// Asks the backend for the top 5 picks among the restaurants on screen.
    func recommend() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                recommendations = try await functionManager.recommendations(
                    placeIds: displayedLocations.map(\.id),
                    lat: latitude,
                    lng: longitude,
                    date: Date()
                )
                if recommendations.isEmpty {
                    errorMessage = "No new restaurants to recommend here."
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't get recommendations."
            }
        }
    }

    /// Refreshes which places the user has visited or reviewed.
    func loadTriedPlaces() async {
        do {
            triedPlaceIds = try await functionManager.triedPlaceIds()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load visited restaurants."
        }
    }

    /// Moves the map to a search center, zoomed so the whole search radius fits.
    private func center(on coordinate: CLLocationCoordinate2D) {
        let meters = max(radius, 0.5) * 1609 * 2.4
        withAnimation {
            camera = .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters))
        }
    }

    private func zoom(by factor: Double) {
        guard let region = visibleRegion else { return }
        let span = MKCoordinateSpan(
            latitudeDelta: min(max(region.span.latitudeDelta * factor, 0.002), 60),
            longitudeDelta: min(max(region.span.longitudeDelta * factor, 0.002), 60)
        )
        withAnimation {
            camera = .region(MKCoordinateRegion(center: region.center, span: span))
        }
    }

    private func milesText(_ miles: Double) -> String {
        "\(miles.formatted(.number.precision(.fractionLength(0...1)))) mi"
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                mapCard

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.horizontal)
                }

                searchCard
                    .padding(.horizontal)

                filterRow

                recommendationsSection

                resultsSection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .overlay {
            // Opening a restaurant takes a moment, so show that something is happening
            if isSubmitting && !locations.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .navigationTitle("Discover")
        .onAppear {
            // Ask for location early so the map can start where you are
            locationManager.checkLocationAuthorization()
        }
        .task {
            await loadTriedPlaces()
        }
        // Visiting or reviewing happens in the sheet, so refresh when it closes.
        .sheet(isPresented: $showModal, onDismiss: {
            Task { await loadTriedPlaces() }
        }) {
            ModalContentView(
                location: location,
                hours: hours,
                restaurantName: restaurantName,
                placeId: selectedPlaceId,
                distance: distance,
                showVisited: false,
                userReviews: userReviews,
                restaurantReview: restaurantReview,
                photoUrl: photoUrl,
                cuisine: selectedCuisine
            )
        }
    }

    // MARK: - Sections

    private var mapCard: some View {
        Map(position: $camera, selection: $selectedPin) {
            UserAnnotation()
            ForEach(displayedLocations) { location in
                if let lat = location.lat, let lng = location.lng {
                    Marker(location.name, monogram: Text(CuisineStyle.of(location.cuisine).emoji), coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                        .tint(Brand.accent)
                        .tag(location.id)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
        }
        .onChange(of: selectedPin) { _, placeId in
            guard let placeId, let location = locations.first(where: { $0.id == placeId }) else { return }
            open(placeId: placeId, name: location.name, cuisine: location.cuisine)
            selectedPin = nil  // so tapping the same pin again works
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            zoomControls
        }
        .padding(.horizontal)
    }

    private var zoomControls: some View {
        VStack(spacing: 0) {
            Button {
                zoom(by: 0.5)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Zoom in")

            Divider()
                .frame(width: 24)

            Button {
                zoom(by: 2)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Zoom out")
        }
        .buttonStyle(.plain)
        .font(.body.weight(.semibold))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(12)
    }

    private var searchCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search an address or neighborhood", text: $address)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onChange(of: address) { _, newValue in
                        // A programmatic fill from a tapped suggestion: swallow it.
                        if isSelectingSuggestion {
                            isSelectingSuggestion = false
                            return
                        }

                        // Cancel whatever fetch was pending — the query changed.
                        autocompleteTask?.cancel()

                        let query = newValue.trimmingCharacters(in: .whitespaces)
                        guard query.count >= 2 else {
                            suggestions = []
                            return
                        }

                        // Wait 1s; if another keystroke lands first, the cancel
                        // above kills this task before the sleep finishes.
                        autocompleteTask = Task {
                            try? await Task.sleep(for: .seconds(1))
                            if Task.isCancelled { return }
                            let results = try? await functionManager.autocomplete(text: query)
                            if Task.isCancelled { return }
                            suggestions = results ?? []
                        }
                    }
                    .onSubmit {
                        // Enter picks the top suggestion, or falls back to the raw text.
                        if let first = suggestions.first {
                            selectSuggestion(first)
                        } else if !address.isEmpty {
                            pickLocation(address: address, radius: radius)
                        }
                    }

                if !address.isEmpty {
                    Button {
                        address = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if !suggestions.isEmpty {
                ForEach(suggestions) { suggestion in
                    Divider()
                        .padding(.leading, 44)
                    Button {
                        selectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Brand.accent)
                            Text(suggestion.text)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Picker("Search radius", selection: $radius) {
                        ForEach(radiusOptions, id: \.self) { miles in
                            Text(milesText(miles)).tag(miles)
                        }
                    }
                } label: {
                    chip("Within \(milesText(radius))", systemImage: "scope", isOn: false)
                }

                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    chip(sortOption.rawValue, systemImage: "arrow.up.arrow.down", isOn: sortOption != .bestMatch)
                }

                ForEach(Meal.allCases) { meal in
                    let isOn = selectedMeals.contains(meal)
                    Button {
                        if isOn {
                            selectedMeals.remove(meal)
                        } else {
                            selectedMeals.insert(meal)
                        }
                    } label: {
                        chip(meal.label, systemImage: meal.icon, isOn: isOn)
                    }
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }

                Button {
                    showOpenNow.toggle()
                } label: {
                    chip("Open Now", systemImage: "clock", isOn: showOpenNow)
                }
                .accessibilityAddTraits(showOpenNow ? .isSelected : [])

                Button {
                    showNewOnly.toggle()
                } label: {
                    chip("New to Me", systemImage: "sparkles", isOn: showNewOnly)
                }
                .accessibilityAddTraits(showNewOnly ? .isSelected : [])
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .buttonStyle(.plain)
    }

    /// A filter chip: filled with the brand color when it's on.
    private func chip(_ title: String, systemImage: String, isOn: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(isOn ? Brand.accent : Color(.secondarySystemGroupedBackground), in: Capsule())
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Picked for You", systemImage: "sparkles", caption: "Based on people who eat like you")
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(recommendations) { recommendation in
                            Button {
                                open(placeId: recommendation.placeId, name: recommendation.name, cuisine: recommendation.cuisine)
                            } label: {
                                RecommendationCard(recommendation: recommendation)
                            }
                            .buttonStyle(.plain)
                            .disabled(isSubmitting)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !locations.isEmpty {
                let shown = displayedLocations.count
                SectionHeader(
                    title: "Nearby",
                    systemImage: "fork.knife",
                    caption: shown == locations.count ? "\(shown) places" : "\(shown) of \(locations.count) places"
                )
            }

            if locations.isEmpty {
                if isSubmitting {
                    ProgressView("Finding places to eat…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ContentUnavailableView {
                        Label("Find your next meal", systemImage: "fork.knife")
                    } description: {
                        Text("Tap Find Food, or search an address to see restaurants around it.")
                    }
                }
            } else if displayedLocations.isEmpty {
                ContentUnavailableView {
                    Label("No matches", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("No restaurants match these filters.")
                } actions: {
                    Button("Clear Filters") {
                        selectedMeals = []
                        showOpenNow = false
                        showNewOnly = false
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(displayedLocations) { location in
                        Button {
                            open(placeId: location.id, name: location.name, cuisine: location.cuisine)
                        } label: {
                            RestaurantRow(location: location)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)

                        if location.id != displayedLocations.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .padding(.horizontal)
    }

    private var bottomBar: some View {
        let hasAddress = !address.trimmingCharacters(in: .whitespaces).isEmpty
        return GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    findFood()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: hasAddress ? "magnifyingglass" : "location.fill")
                        }
                        Text(hasAddress ? "Search" : "Find Food")
                    }
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(isSubmitting)

                Button {
                    recommend()
                } label: {
                    Label("Recommend", systemImage: "sparkles")
                        .font(.headline)
                }
                .buttonStyle(.glass)
                .disabled(isSubmitting || displayedLocations.isEmpty)
            }
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}


#Preview("Location") {
    let apiClient = APIClient(baseURL: AppEnvironment.apiBaseURL)
    LocationView()
        .environment(FunctionManager(apiClient: apiClient))
}
