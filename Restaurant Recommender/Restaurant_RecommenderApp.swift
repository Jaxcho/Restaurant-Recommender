//
//  Restaurant_RecommenderApp.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 5/17/26.
//

import SwiftUI

@main
struct Restaurant_RecommenderApp: App {
    
    @State private var authManager = AuthManager(apiClient: APIClient(baseURL: AppEnvironment.apiBaseURL))
    @State private var functionManager = FunctionManager(apiClient: APIClient(baseURL: AppEnvironment.apiBaseURL))
    
    var body: some Scene {
        WindowGroup {
            RootView().environment(authManager)
                .environment(functionManager)
        }
    }
}
