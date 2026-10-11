//
//  ProfileView.swift
//  Restaurant Recommender
//
//  Account and settings: taste profile, today's cravings, light/dark mode, log out.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(FunctionManager.self) private var functionManager
    @AppStorage(SettingsKey.appearance) private var appearance: Appearance = .system
    @AppStorage(SettingsKey.askCravingsOnLaunch) private var askCravingsOnLaunch: Bool = true
    @State private var username: String?
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false
    @State private var showCravings: Bool = false

    private func loadUser() async {
        errorMessage = nil
        do {
            username = try await functionManager.me().username
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load your profile."
        }
    }

    // RootView clears the party and cravings on this phone once logged out
    private func logout() {
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            await authManager.logout()
        }
    }

    /// "Japanese, Korean", or "Anything" when nothing is picked.
    private var cravingsSummary: String {
        let labels = functionManager.cravings.map { CuisineStyle.of($0).label }.sorted()
        return labels.isEmpty ? "Anything" : labels.joined(separator: ", ")
    }

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    ErrorBanner(message: errorMessage)
                }
                .listRowInsets(EdgeInsets())
            }

            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Brand.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(username ?? " ")
                            .font(.headline)
                        Text("Signed in")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Preferences") {
                NavigationLink {
                    TasteProfileView()
                } label: {
                    Label("Taste Profile", systemImage: "heart")
                }

                Button {
                    showCravings = true
                } label: {
                    LabeledContent {
                        Text(cravingsSummary)
                            .lineLimit(1)
                    } label: {
                        Label("Today's Cravings", systemImage: "fork.knife")
                    }
                }
                .tint(.primary)

                Toggle(isOn: $askCravingsOnLaunch) {
                    Label("Ask When I Open the App", systemImage: "bell")
                }
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section {
                Button("Log Out", role: .destructive) {
                    logout()
                }
                .disabled(isSubmitting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Profile")
        .task {
            await loadUser()
        }
        .sheet(isPresented: $showCravings) {
            CravingView()
        }
    }
}

#Preview {
    let apiClient = APIClient(baseURL: AppEnvironment.apiBaseURL)
    NavigationStack {
        ProfileView()
    }
    .environment(AuthManager(apiClient: apiClient))
    .environment(FunctionManager(apiClient: apiClient))
}
