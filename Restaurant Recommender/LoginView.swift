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
    @State private var showPassword: Bool = false
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
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't log in. Please try again."
            }
        }
    }

    
    var body: some View {
        Form {
            Section {
                header
            }
            .listRowBackground(Color.clear)

            Section {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                HStack {
                    // Showing it as plain text lets you check your capitals
                    if showPassword {
                        TextField("Password", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Password", text: $password)
                    }
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                }
                .textContentType(.password)
            }

            if !errorMessage.isEmpty {
                Section {
                    errorBanner
                }
                .listRowBackground(Color.red.opacity(0.12))
            }

            Section {
                submitButton
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .navigationTitle("Log In")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .shadow(color: Brand.accent.opacity(0.3), radius: 8, y: 4)
                .accessibilityHidden(true)
            Text("Welcome back")
                .font(.title2.bold())
            Text("Log in to see restaurants picked for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var errorBanner: some View {
        Label {
            Text(errorMessage)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
        .font(.callout)
    }

    private var submitButton: some View {
        Button(action: login) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                }
                Text(isSubmitting ? "Logging In…" : "Log In")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(isSubmitting || username.isEmpty || password.isEmpty)
    }
}

//#Preview {
////    LoginView()
//}
