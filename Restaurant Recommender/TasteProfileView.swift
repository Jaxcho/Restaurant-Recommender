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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 44
    @State private var cuisines: Array<CuisineDTO> = []
    @State private var scores: [String: Int] = [:]
    @State private var errorMessage: String?
    @State private var isSubmitting: Bool = false
    @State private var isLoading: Bool = true
    @State private var justSaved: Bool = false

    func load() async {
        errorMessage = nil
        isLoading = true
        defer {
            isLoading = false
        }
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
                // Closes the onboarding sheet, or goes back to Profile
                // (so the "Saved" label below never actually shows now)
                justSaved = true
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

    private var lovedCount: Int {
        cuisines.filter { scores[$0.key] == 1 }.count
    }

    private var skippedCount: Int {
        cuisines.filter { scores[$0.key] == -1 }.count
    }

    private var summary: String {
        if cuisines.isEmpty {
            return ""
        }
        return "\(lovedCount) loved · \(skippedCount) skipped"
    }

    var body: some View {
        List {
            Section {
                header
            }

            if !cuisines.isEmpty {
                Section {
                    ForEach(cuisines) { cuisine in
                        cuisineRow(cuisine)
                    }
                } footer: {
                    Text("Not sure? Leave it neutral. Your reviews keep updating this.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .navigationTitle("Taste Profile")
        .navigationSubtitle(summary)
        .overlay {
            if isLoading && cuisines.isEmpty {
                ProgressView()
            } else if cuisines.isEmpty {
                loadFailedView
            }
        }
        .safeAreaBar(edge: .bottom) {
            if !cuisines.isEmpty {
                saveBar
            }
        }
        .task {
            await load()
        }
        // Turns "Saved" back into "Save" after 2 seconds
        .task(id: justSaved) {
            guard justSaved else { return }
            try? await Task.sleep(for: .seconds(2))
            justSaved = false
        }
        // Buzz when "Saved" appears, not when it goes away
        .sensoryFeedback(.success, trigger: justSaved) { _, isSaved in
            isSaved
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.headline)
                .foregroundStyle(Brand.accent)
                .frame(width: circleSize, height: circleSize)
                .background(Brand.accent.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            Text("Heart what you love, thumbs-down what you skip. We'll find people who eat like you.")
                .font(.callout)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cuisineRow(_ cuisine: CuisineDTO) -> some View {
        // Very large text: the buttons go under the name so nothing gets squeezed
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                cuisineName(cuisine)
                tasteButtons(for: cuisine)
            }
        } else {
            HStack(spacing: 12) {
                cuisineName(cuisine)
                Spacer(minLength: 8)
                tasteButtons(for: cuisine)
            }
        }
    }

    private func cuisineName(_ cuisine: CuisineDTO) -> some View {
        HStack(spacing: 12) {
            CuisineBadge(cuisine: cuisine.key)
            Text(cuisine.label)
        }
    }

    private func tasteButtons(for cuisine: CuisineDTO) -> some View {
        let score = scores[cuisine.key] ?? 0
        return HStack(spacing: 8) {
            tasteButton(
                isOn: score == -1,
                onImage: "hand.thumbsdown.fill",
                offImage: "hand.thumbsdown",
                onColor: .primary,
                voiceOverLabel: "Not for me: \(cuisine.label)"
            ) {
                setScore(-1, for: cuisine.key)
            }
            tasteButton(
                isOn: score == 1,
                onImage: "heart.fill",
                offImage: "heart",
                onColor: .pink,
                voiceOverLabel: "Love \(cuisine.label)"
            ) {
                setScore(1, for: cuisine.key)
            }
        }
    }

    private func tasteButton(isOn: Bool, onImage: String, offImage: String, onColor: Color, voiceOverLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isOn ? onImage : offImage)
                .font(.title3)
                .foregroundStyle(isOn ? onColor : Color.secondary)
                .frame(width: circleSize, height: circleSize)
                .background(isOn ? onColor.opacity(0.18) : Color(.tertiarySystemFill), in: Circle())
                .symbolEffect(.bounce, value: isOn)
        }
        // .borderless stops one tap from firing every button in the row
        .buttonStyle(.borderless)
        .accessibilityLabel(voiceOverLabel)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var saveBar: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                errorBanner(errorMessage)
            }
            if lovedCount + skippedCount < 3 {
                Label("Pick at least 3 for better picks", systemImage: "lightbulb")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            saveButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                } else if justSaved {
                    Image(systemName: "checkmark")
                }
                Text(saveButtonTitle)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(isSubmitting || cuisines.isEmpty)
    }

    private var saveButtonTitle: String {
        if isSubmitting {
            return "Saving…"
        }
        if justSaved {
            return "Saved"
        }
        return "Save"
    }

    private func errorBanner(_ message: String) -> some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        // A solid layer under the red tint so the list can't show through it
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var loadFailedView: some View {
        ContentUnavailableView {
            Label("Couldn't load cuisines", systemImage: "wifi.exclamationmark")
        } description: {
            Text(errorMessage ?? "Check your connection and try again.")
        } actions: {
            Button("Try Again") {
                Task {
                    await load()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
