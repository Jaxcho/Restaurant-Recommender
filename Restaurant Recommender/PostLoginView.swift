//
//  PostLoginView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI

struct PostLoginView: View {
    @Environment(FunctionManager.self) private var functionManager
    @AppStorage(SettingsKey.askCravingsOnLaunch) private var askCravingsOnLaunch: Bool = true
    @State private var errorMessage: String? = nil
    @State private var showTasteProfile: Bool = false
    @State private var showCravings: Bool = false

    var body: some View {
        TabView {
            Tab("Discover", systemImage: "fork.knife") {
                NavigationStack {
                    LocationView()
                }
            }
            Tab("Party", systemImage: "person.3") {
                NavigationStack {
                    PartyHomeView()
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
            Tab("Profile", systemImage: "person.crop.circle") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // Runs after every login and every launch with a saved login.
        // First time in (no taste profile yet): ask for one. Otherwise ask what
        // they feel like today, unless they turned that off.
        .task {
            guard let scores = try? await functionManager.preferences() else { return }
            if scores.isEmpty {
                showTasteProfile = true
            } else if askCravingsOnLaunch {
                showCravings = true
            }
        }
        .sheet(isPresented: $showCravings) {
            CravingView()
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


