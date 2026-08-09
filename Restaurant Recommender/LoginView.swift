//
//  LoginView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 5/17/26.
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
        Form {
            Section {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            Button("Log In", action: login)
                .disabled(isSubmitting)
                .frame(maxWidth: .infinity)
        }
        .navigationTitle("Log In")
    }
}

//#Preview {
////    LoginView()
//}
