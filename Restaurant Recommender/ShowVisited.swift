//
//  ShowVisited.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 7/23/26.
//

import SwiftUI


struct ShowVisited: View {
    @Environment(FunctionManager.self) private var functionManager
    @State private var name: String = ""
    @State private var placeId: String = ""
    @State private var location: String = ""
    @State private var hours: String = ""
    @State private var id: Int = 0
    @State private var errorMessage: String? = nil
    @State private var isSubmitting: Bool = false
    @State private var locations: Array<VisitedRestaurantDTO> = []
    func sendLocation() {
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
    
    
    
    var body: some View {
        Text("Locations")
        .onAppear {
            sendLocation()
        }
        List(locations){ location in
            HStack {
                Text(location.name)
                
            }
        }
    }
}
