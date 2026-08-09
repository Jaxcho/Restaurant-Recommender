//
//  PostLoginView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI

struct PostLoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var errorMessage: String? = nil
    
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
                }
            }
            .navigationTitle("Restaurant Radar")
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


