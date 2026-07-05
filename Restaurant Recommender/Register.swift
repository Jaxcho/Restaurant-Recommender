//
//  Register.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//

import SwiftUI

struct RegisterView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var username: String = "";
    @State private var password: String = "";
    @State private var isSubmitting: Bool = false;
    @State private var errorMessage: String = "";
    
    func register(){
        isSubmitting = true;
        if username == "" || password == "" {
            isSubmitting = false
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
            SecureField("Password", text: $password)
            Button("Register", action: register).disabled(isSubmitting)
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
    }
}
