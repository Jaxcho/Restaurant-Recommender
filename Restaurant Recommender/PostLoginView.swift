//
//  PostLoginView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI

struct PostLoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(FunctionManager.self) private var functionManager
    @State private var errorMessage: String? = nil
    @State private var showTasteProfile: Bool = false
    
    func logout(){
        Task {
            defer {
              
            }
            
            await authManager.logout()
           
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: LocationView()) {
                        Label("Find Restaurants", systemImage: "magnifyingglass")
                    }
                    NavigationLink(destination: ShowVisited()) {
                        Label("Visited Restaurants", systemImage: "checkmark.circle")
                    }
                    NavigationLink(destination: WantToGoView()) {
                        Label("Want to Go", systemImage: "bookmark")
                    }
                    NavigationLink(destination: TasteProfileView()) {
                        Label("Taste Profile", systemImage: "heart")
                    }
                }
            }
            .navigationTitle("Restaurant Radar")
            .task {
                // First time in (no taste profile saved yet): ask for one
                if let scores = try? await functionManager.preferences(), scores.isEmpty {
                    showTasteProfile = true
                }
            }
            .sheet(isPresented: $showTasteProfile) {
                NavigationStack {
                    TasteProfileView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Skip") {
                                    showTasteProfile = false
                                }
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout", role: .destructive) {
                        logout()
                    }
                }
            }
        }
    }
}


