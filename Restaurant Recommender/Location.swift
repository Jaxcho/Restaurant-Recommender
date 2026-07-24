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
    @Environment(FunctionManager.self) private var functionManager
    // Environment property to dismiss the view programmatically
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(restaurantReview)
                .font(.title)
                .bold()
            
            Text("\(distance)")
            
            Text("Swipe down to dismiss or tap the button below.")
                .multilineTextAlignment(.center)
            
            Button("Dismiss") {
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Button("Mark Visited!") {
                Task {
                    try await functionManager.visited(placeId: placeId)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct LocationView: View {
    @State private var camera: MapCameraPosition = .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), distance: 500))
    @State private var locationManager = LocationModel()
    @Environment(FunctionManager.self) private var functionManager
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var errorMessage: String?
    @State private var radius: Int = 1
    @State private var time: Date = Date()
    @State private var isSubmitting: Bool = false
    @State private var locations: Array<FoundLocationsDTO> = [];
    @State private var restaurantReview: String = ""
    @State private var showModal = false
    @State private var location: Array<Double> = []
    @State private var hours: Array<OpeningHoursStruct> = []
    @State private var restaurantName: String = "";
    @State private var distance: Double = 0;
    
    @State private var selectedPlaceId: String = "" // This is the current restaurant id that the modal uses that is used in mark visited
    
    func sendLocation(_ latitude: Double, _ longitude: Double ,_ radius: Int, _ time: Date){
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
    
    func visited(place_id: String){
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                try await functionManager.visited(placeId: place_id)
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
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            VStack {
                Map(position: $camera) {
                    if let coordinate = locationManager.lastKnownLocation {
                        Marker("You", coordinate: coordinate)
                        }
                    }.frame(height: 200)
            Button("Zoom Out") {
                if let cam = camera.camera {
                    camera = .camera(MapCamera(centerCoordinate: cam.centerCoordinate, distance: cam.distance * 2))
                }
            }
            Button("Zoom In") {
                if let cam = camera.camera {
                    camera = .camera(MapCamera(centerCoordinate: cam.centerCoordinate, distance: cam.distance * 0.5))
                }
            }
                List(locations) { location in
                    HStack {
                        Text(location.name)
                        Button(">") {
                            selectedPlaceId = location.id
                            restaurantData(restaurant_id: location.id, restaurant_name: location.name)
                        }.disabled(isSubmitting)
                        
                    }
                }
                
                Button("Get location") {
                    locationManager.checkLocationAuthorization()
                    if let coordinate = locationManager.lastKnownLocation {
                        latitude = coordinate.latitude;
                        longitude = coordinate.longitude;
                        radius = 1;
                        time = Date();
                        if let cam = camera.camera {
                            camera = .camera(MapCamera(centerCoordinate: coordinate, distance: cam.distance))
                        }
                    }
                    
                }
                
                .buttonStyle(.borderedProminent)
                Button("Send Location") {
                    sendLocation(latitude, longitude, radius, time)
                    
                }.disabled(isSubmitting)
                
                
            }

            .padding()
            .sheet(isPresented: $showModal) {
                ModalContentView(location: location, hours: hours, restaurantReview: restaurantReview, restaurantName: restaurantName, placeId: selectedPlaceId, distance: distance)
            }
        }
    }

