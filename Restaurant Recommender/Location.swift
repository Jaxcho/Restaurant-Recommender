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
    
    
    func checkLocationAuthorization() {
        
        manager.delegate = self

        switch manager.authorizationStatus {
        case .notDetermined://The user choose allow or denny your app to get the location yet
            manager.requestWhenInUseAuthorization()
            
        case .restricted://The user cannot change this app’s status, possibly due to active restrictions such as parental controls being in place.
            print("Location restricted")
            
        case .denied://The user dennied your app to get location or disabled the services location or the phone is in airplane mode
            print("Location denied")
            
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

    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location failed: \(error.localizedDescription)")
    }
}

struct ModalContentView: View {
    
    let location: Array<Double>
    let hours: Array<OpeningHoursStruct>
    let restaurantReview: String
    let restaurantName: String
    let placeId: String
    let distance: Double
    let showVisited: Bool
    let 
    @State private var dateVisited: Date = Date()
    
    @Environment(FunctionManager.self) private var functionManager
    // Environment property to dismiss the view programmatically
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(restaurantName)
                .font(.title2)
                .bold()

            if showVisited == false {
                Label("\(distance, specifier: "%.1f") away", systemImage: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            ScrollView {
                if restaurantReview.isEmpty {
                    Text("No review summary available.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(restaurantReview)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            

            if showVisited == false {
                DatePicker("Date visited", selection: $dateVisited, displayedComponents: .date)

                Button {
                    Task {
                        try await functionManager.visited(placeId: placeId, dateVisited: dateVisited)
                        dismiss()
                    }
                } label: {
                    Label("Mark Visited", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Dismiss") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct LocationView: View {
    @State private var camera: MapCameraPosition = .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), distance: 500))
    @State private var locationManager = LocationModel()
    @Environment(FunctionManager.self) private var functionManager
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var errorMessage: String?
    @State private var radius: Double = 1.0
    @State private var time: Date = Date()
    @State private var isSubmitting: Bool = false
    @State private var locations: Array<FoundLocationsDTO> = [];
    @State private var restaurantReview: String = ""
    @State private var showModal = false
    @State private var location: Array<Double> = []
    @State private var hours: Array<OpeningHoursStruct> = []
    @State private var restaurantName: String = "";
    @State private var distance: Double = 0;
    @State private var address: String = ""
    @State private var isEditing: Bool = false
    
    @State private var selectedPlaceId: String = "" // This is the current restaurant id that the modal uses that is used in mark visited
    
    func sendLocation(_ latitude: Double, _ longitude: Double ,_ radius: Double, _ time: Date){
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                locations = try await functionManager.location(lat: latitude, lng: longitude, radius: radius, time: time)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Uh oh"
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
                latitude = response.lat
                longitude = response.lng
                let coordinate = CLLocationCoordinate2D(latitude: response.lat, longitude: response.lng)
                if let cam = camera.camera {
                    camera = .camera(MapCamera(centerCoordinate: coordinate, distance: cam.distance))
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Uh oh"
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
        VStack(spacing: 12) {
            Map(position: $camera) {
                if let coordinate = locationManager.lastKnownLocation {
                    Marker("You", coordinate: coordinate)
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    Button {
                        if let cam = camera.camera {
                            camera = .camera(MapCamera(centerCoordinate: cam.centerCoordinate, distance: cam.distance * 0.5))
                        }
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 36, height: 36)
                    }
                    Divider()
                        .frame(width: 36)
                    Button {
                        if let cam = camera.camera {
                            camera = .camera(MapCamera(centerCoordinate: cam.centerCoordinate, distance: cam.distance * 2))
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 36, height: 36)
                    }
                }
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(8)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                TextField("Search by address", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit {
                        if !address.isEmpty {
                            pickLocation(address: address, radius: radius)
                        }
                    }
                Button {
                    pickLocation(address: address, radius: radius)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting || address.isEmpty)
            }

            VStack(spacing: 2) {
                Slider(value: $radius, in: 0...50) { editing in
                    isEditing = editing
                }
                Text("Radius: \(radius, specifier: "%.0f") mi")
                    .font(.footnote)
                    .foregroundStyle(isEditing ? .primary : .secondary)
            }

            List(locations) { location in
                Button {
                    selectedPlaceId = location.id
                    restaurantData(restaurant_id: location.id, restaurant_name: location.name)
                } label: {
                    HStack {
                        Text(location.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isSubmitting)
            }
            .listStyle(.plain)
            .overlay {
                if locations.isEmpty {
                    ContentUnavailableView(
                        "No restaurants yet",
                        systemImage: "fork.knife",
                        description: Text("Search an address or use your location.")
                    )
                }
            }

            HStack {
                Button {
                    locationManager.checkLocationAuthorization()
                    if let coordinate = locationManager.lastKnownLocation {
                        latitude = coordinate.latitude
                        longitude = coordinate.longitude
                        time = Date()
                        if let cam = camera.camera {
                            camera = .camera(MapCamera(centerCoordinate: coordinate, distance: cam.distance))
                        }
                    }
                } label: {
                    Label("My Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    sendLocation(latitude, longitude, radius, time)
                } label: {
                    Label("Find Food", systemImage: "fork.knife")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
            }
        }
        .padding()
        .navigationTitle("Find Restaurants")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showModal) {
            ModalContentView(location: location, hours: hours, restaurantReview: restaurantReview, restaurantName: restaurantName, placeId: selectedPlaceId, distance: distance, showVisited: false)
        }
    }
}

