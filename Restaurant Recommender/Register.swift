//
//  Register.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//

import SwiftUI

private struct LoginRequest: Encodable {
    let username: String;
    let password: String;
}

struct RegisterView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var username: String = "";
    @State private var password: String = "";
    @State private var isSubmitting: Bool = false;
    @State private var errorMessage: String? = nil;
    
    @State private var errorMessage: String = "";
    func register(){
        isSubmitting = true;
        if username == "" || password == "" {
            return
        }
        Task {
            defer { isSubmitting = false }
            do {
                try await authManager.register(username: username, password: password)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Uh oh"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            TextField("Username", text: $username)
            TextField("Password", text: $password)
            Button("Register") {
                self.isSubmitting.toggle()
                
                let request = RegisterRequest(username: username, password: password)
            }
        }
    }
}
