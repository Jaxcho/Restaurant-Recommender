//
//  Location.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI
import CoreLocation
import MapKit

final class LocationModel: NSObject, CLLocationManagerDelegate {

    
    private(set) var lastKnownLocation: CLLocationCoordinate2D?
    private let manager = CLLocationManager()
    
    
    func checkLocationAuthorization() {
        
        manager.delegate = self
        manager.startUpdatingLocation()
//        manager.requestWhenInUseAuthorization()
//        print("checking")
        
        switch manager.authorizationStatus {
        case .notDetermined://The user choose allow or denny your app to get the location yet
            manager.requestWhenInUseAuthorization()
            
        case .restricted://The user cannot change this app’s status, possibly due to active restrictions such as parental controls being in place.
            print("Location restricted")
            
        case .denied://The user dennied your app to get location or disabled the services location or the phone is in airplane mode
            print("Location denied")
            
        case .authorizedAlways://This authorization allows you to use all location services and receive location events whether or not your app is in use.
            print("Location authorizedAlways")
            
        case .authorizedWhenInUse://This authorization allows you to use all location services and receive location events only when your app is in use
            print("Location authorized when in use")
            lastKnownLocation = manager.location?.coordinate
            
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
}

struct ModalContentView: View {
    let restaurantReview: String
    let restaurantName: String
    // Environment property to dismiss the view programmatically
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(restaurantReview)
                .font(.title)
                .bold()
            
            Text("Swipe down to dismiss or tap the button below.")
                .multilineTextAlignment(.center)
            
            Button("Dismiss") {
                dismiss()
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
    
    
    func sendLocation(_ latitude: Double, _ longitude: Double ,_ radius: Int, _ time: Date){
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
    
    func restaurantData(restaurant_id: String){
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                restaurantReview = try await functionManager.restaurantInfo(restaurant_id: restaurant_id).reviewSummary
                showModal = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Uh oh"
            }
        }
    }
    
    
        var body: some View {
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
                            restaurantData(restaurant_id: location.id)
                        }
                    }
                    .sheet(isPresented: $showModal) {
                        ModalContentView(restaurantReview: restaurantReview, restaurantName: location.name)
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
                    
                }
                
                
            }
            
            .padding()
        }
    }
