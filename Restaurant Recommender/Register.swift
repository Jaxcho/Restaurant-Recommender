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
    @State private var showPassword: Bool = false

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
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't create your account. Please try again."
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
                HStack {
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
        .navigationTitle("Sign Up")
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
            Text("Create your account")
                .font(.title2.bold())
            Text("Get picks from people who eat like you.")
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
        Button(action: register) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                }
                Text(isSubmitting ? "Creating Account…" : "Create Account")
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
