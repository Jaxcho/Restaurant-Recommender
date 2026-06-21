//
//  Location.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI
import CoreLocation
import Combine

@MainActor
class Location: ObservableObject {
    
    @Published var location: CLLocation?
    
    func startUpdating() async{
        let updates = CLLocationUpdate.liveUpdates()
        do{
            for try await update in updates{
                if let newLocation = update.location{
                    self.location = newLocation
                }
            }
        }
        
        catch{
            print("Location failed: \(error)")
        }
        
    }
}

struct LocationView: View {
    @StateObject private var Loc = Location()
    
    var body: some View {
        VStack (spacing: 16) {
            if let location = Loc.location {
                Text("Latitude: \(location.coordinate.latitude)")
                Text("Longitude: \(location.coordinate.longitude)")
            } else {
                Text("Fetching location...")
            }
        }
        .task {
            await Loc.startUpdating()
        }
    }
}

