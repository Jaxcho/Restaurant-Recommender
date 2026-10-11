//
//  CravingView.swift
//  Restaurant Recommender
//
//  "What are you feeling like today?" The picks become today's cravings:
//  Discover can show only those cuisines and Recommend ranks them higher.
//

import SwiftUI

struct CravingView: View {
    @Environment(FunctionManager.self) private var functionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var tileHeight: CGFloat = 48
    @AppStorage(SettingsKey.askCravingsOnLaunch) private var askOnLaunch: Bool = true
    @State private var cuisines: Array<CuisineDTO> = []
    @State private var selected: Set<String> = []
    @State private var errorMessage: String?
    @State private var isLoading: Bool = true

    // Two columns normally; one when the text is very large so names aren't squeezed
    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer {
            isLoading = false
        }
        do {
            cuisines = try await functionManager.cuisines()
            selected = functionManager.cravings
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load cuisines."
        }
    }

    private func showMe() {
        functionManager.cravings = selected
        dismiss()
    }

    private func anythingGoes() {
        functionManager.cravings = []
        dismiss()
    }

    private func toggle(_ key: String) {
        if selected.contains(key) {
            selected.remove(key)
        } else {
            selected.insert(key)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What are you feeling like today?")
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick as many as you like. Discover will show just these, and Recommend ranks them higher.")
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(cuisines) { cuisine in
                        cuisineButton(cuisine)
                    }
                }

                Toggle("Ask every time I open the app", isOn: $askOnLaunch)
                    .cardStyle()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if isLoading && cuisines.isEmpty {
                ProgressView()
            }
        }
        .safeAreaBar(edge: .bottom) {
            buttons
        }
        .presentationDragIndicator(.visible)
        .task {
            await load()
        }
    }

    private func cuisineButton(_ cuisine: CuisineDTO) -> some View {
        let isOn = selected.contains(cuisine.key)
        return Button {
            toggle(cuisine.key)
        } label: {
            HStack(spacing: 8) {
                Text(CuisineStyle.of(cuisine.key).emoji)
                // Long names wrap onto a second line instead of being cut off
                Text(cuisine.label)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: tileHeight, alignment: .leading)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(isOn ? Brand.accent : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        // VoiceOver reads just the name and "Selected", not the emoji or checkmark
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cuisine.label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isOn)
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button(action: showMe) {
                Text("Show Me")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(selected.isEmpty)

            Button("Anything's fine", action: anythingGoes)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    CravingView()
        .environment(FunctionManager(apiClient: APIClient(baseURL: AppEnvironment.apiBaseURL)))
}
