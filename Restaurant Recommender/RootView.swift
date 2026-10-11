//
//  RootView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/8/26.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(FunctionManager.self) private var functionManager
    @Environment(PartyManager.self) private var partyManager

    var body: some View {
        Group {
            if authManager.isBootstrapping {
                splash
            } else if authManager.isAuthenticated {
                PostLoginView()
            } else {
                UnauthenticatedView()
            }
        }
        .animation(.default, value: authManager.isBootstrapping)
        // Any logout (button or expired session): forget this user's state on the phone.
        // The party stays saved on the server and comes back after logging in again.
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                partyManager.reset()
                functionManager.cravings = []
            }
        }
    }

    // Shown at launch while a saved login is being checked
    private var splash: some View {
        VStack(spacing: 24) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .shadow(color: Brand.accent.opacity(0.35), radius: 16, y: 8)
                .accessibilityHidden(true)
            ProgressView()
        }
    }
}

#Preview {
    // Same setup as Restaurant_RecommenderApp, so login hits the real backend.
    let apiClient = APIClient(baseURL: AppEnvironment.apiBaseURL)
    RootView()
        .environment(AuthManager(apiClient: apiClient))
        .environment(FunctionManager(apiClient: apiClient))
        .environment(PartyManager(apiClient: apiClient))
}
