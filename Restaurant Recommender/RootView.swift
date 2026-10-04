//
//  RootView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/8/26.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    
    
    var body: some View {
        Group {
            if authManager.isBootstrapping {
                ProgressView()
            } else if authManager.isAuthenticated {
                PostLoginView()
            } else {
                UnauthenticatedView()
            }
        }
        
    }
}

#Preview {
    // Same setup as Restaurant_RecommenderApp, so login hits the real backend.
    let apiClient = APIClient(baseURL: AppEnvironment.apiBaseURL)
    RootView()
        .environment(AuthManager(apiClient: apiClient))
        .environment(FunctionManager(apiClient: apiClient))
}
