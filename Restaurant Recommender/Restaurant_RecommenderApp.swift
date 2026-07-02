//
//  Restaurant_RecommenderApp.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 5/17/26.
//

import SwiftUI

@main
struct Restaurant_RecommenderApp: App {

    @State private var authManager: AuthManager
    @State private var functionManager: FunctionManager

    init() {
        let apiClient = APIClient(baseURL: AppEnvironment.apiBaseURL)
        _authManager = State(initialValue: AuthManager(apiClient: apiClient))
        _functionManager = State(initialValue: FunctionManager(apiClient: apiClient))
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(authManager)
                .environment(functionManager)
        }
    }
}
