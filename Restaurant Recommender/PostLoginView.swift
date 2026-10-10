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
        TabView {
            Tab("Discover", systemImage: "fork.knife") {
                NavigationStack {
                    LocationView()
                }
            }
            Tab("Want to Go", systemImage: "bookmark") {
                NavigationStack {
                    WantToGoView()
                }
            }
            Tab("Visited", systemImage: "checkmark.seal") {
                NavigationStack {
                    ShowVisited()
                }
            }
            Tab("Taste", systemImage: "heart") {
                NavigationStack {
                    TasteProfileView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Log Out", role: .destructive) {
                                    logout()
                                }
                            }
                        }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
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
    }
}


