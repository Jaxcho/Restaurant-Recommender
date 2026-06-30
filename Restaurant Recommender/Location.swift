//
//  Location.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI
import CoreLocation
import Combine

final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {


    @Published var lastKnownLocation: CLLocationCoordinate2D?
    var manager = CLLocationManager()
    
    
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
//
//@MainActor
//class Location: ObservableObject {
//    
//    @Published var location: CLLocation?
//    
//    func startUpdating() async{
//        let updates = CLLocationUpdate.liveUpdates()
//        do{
//            for try await update in updates{
//                if let newLocation = update.location{
//                    self.location = newLocation
//                }
//            }
//        }
//        
//        catch{
//            print("Location failed: \(error)")
//        }
//        
//    }
//}

struct LocationView: View {
    @StateObject private var locationManager = LocationManager()
    @Environment(FunctionManager.self) private var functionManager
    @State private var latitude : Double
    @State private var longitude : Double
    @State private var errorMessage: String?
    @State private var radius: Int
    @State private var time: Date
    @State private var isSubmitting: Bool = false
    @State private var locations: Array<FoundLocationsDTO> = [];
    
    
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
    
    
        var body: some View {
            VStack {
                List(locations) { location in
                    Text(location.name)
                }
//                if let coordinate = locationManager.lastKnownLocation {
//                    Text("Latitude: \(coordinate.latitude)")
//                    
//                    Text("Longitude: \(coordinate.longitude)")
//                    
//                    Text("Radius" \(coordinate.radius))
//                    
//                    Text("Time" \(coordinate.time))
//                } else {
//                    Text("Unknown Location")
//                    
//                }
                
                
                Button("Get location") {
                    locationManager.checkLocationAuthorization()
                    if let coordinate = locationManager.lastKnownLocation {
                        latitude = coordinate.latitude;
                        longitude = coordinate.longitude;
                        radius = 1;
                        time = Date();
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

//    @StateObject private var Loc = Location()
//    
//    var body: some View {
//        VStack (spacing: 16) {
//            if let location = Loc.location {
//                Text("Latitude: \(location.coordinate.latitude)")
//                Text("Longitude: \(location.coordinate.longitude)")
//            } else {
//                Text("Fetching location...")
//            }
//        }
//        .task {
//            await Loc.startUpdating()
//        }
//    }
//}
//
