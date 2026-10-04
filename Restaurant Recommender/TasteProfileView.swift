//
//  TasteProfileView.swift
//  Restaurant Recommender
//

import SwiftUI

/// Lets the user rate each cuisine: love it (1), neutral (0), or not for me (-1).
/// This is the starting point of their taste profile; reviews keep updating it.
struct TasteProfileView: View {
    @Environment(FunctionManager.self) private var functionManager
    @Environment(\.dismiss) private var dismiss
    @State private var cuisines: Array<CuisineDTO> = []
    @State private var scores: [String: Int] = [:]
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false

    func load() async {
        errorMessage = nil
        do {
            // Assign only after both succeed, so Save stays disabled on failure
            // and can't overwrite the saved profile with all-neutral scores.
            let loadedCuisines = try await functionManager.cuisines()
            let loadedScores = try await functionManager.preferences()
            cuisines = loadedCuisines
            scores = loadedScores
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't load cuisines."
        }
    }

    func save() {
        errorMessage = nil
        isSubmitting = true
        Task {
            defer {
                isSubmitting = false
            }
            do {
                // Send every cuisine in the server's order; untouched ones go as 0
                try await functionManager.savePreferences(scores: scores, order: cuisines.map(\.key))
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save."
            }
        }
    }

    // Tapping the button that's already active puts the cuisine back to neutral
    private func setScore(_ score: Int, for key: String) {
        scores[key] = scores[key] == score ? 0 : score
    }

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Section {
                ForEach(cuisines) { cuisine in
                    let score = scores[cuisine.key] ?? 0
                    HStack(spacing: 20) {
                        Text(cuisine.label)
                        Spacer()
                        // .borderless stops one tap from firing every button in the row
                        Button {
                            setScore(-1, for: cuisine.key)
                        } label: {
                            Image(systemName: score == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .foregroundStyle(score == -1 ? Color.orange : Color.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Not for me: \(cuisine.label)")
                        .accessibilityAddTraits(score == -1 ? .isSelected : [])

                        Button {
                            setScore(1, for: cuisine.key)
                        } label: {
                            Image(systemName: score == 1 ? "heart.fill" : "heart")
                                .foregroundStyle(score == 1 ? Color.pink : Color.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Love \(cuisine.label)")
                        .accessibilityAddTraits(score == 1 ? .isSelected : [])
                    }
                    .imageScale(.large)
                }
            } footer: {
                Text("Love it, skip it, or leave it neutral. Your reviews keep updating this.")
            }
        }
        .navigationTitle("Taste Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(isSubmitting || cuisines.isEmpty)
            }
        }
        .task {
            await load()
        }
    }
}
