//
//  LoginView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 5/17/26.

//alice
//secret123
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false;
    
    @State private var errorMessage: String = "";
    func login(){
        isSubmitting = true;
        if username == "" || password == "" {
            isSubmitting = false
            return
        }
        Task {
            defer { isSubmitting = false }
            do {
                try await authManager.login(username: username, password: password)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Uh oh"
            }
        }
    }

    
    var body: some View {
        TextField("Username", text: $username)
        SecureField("Password", text: $password)
        Button("Submit", action: login).disabled(isSubmitting)
        if !errorMessage.isEmpty {
            Text(errorMessage)
                .foregroundColor(.red)
        }
    }
}

//#Preview {
////    LoginView()
//}
