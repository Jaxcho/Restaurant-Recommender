//
//  Unathenticated.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/21/26.
//

import SwiftUI

struct UnauthenticatedView: View {
    @ScaledMetric(relativeTo: .title3) private var featureIconSize: CGFloat = 44

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    hero
                    features
                }
                // Keeps lines a readable length on iPad
                .frame(maxWidth: 480)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Centers the content when it is shorter than the screen
            .defaultScrollAnchor(.center, for: .alignment)
            .safeAreaBar(edge: .bottom) {
                actions
            }
            .background(warmBackground)
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .shadow(color: Brand.accent.opacity(0.35), radius: 16, y: 8)
                .padding(.bottom, 8)
                .accessibilityHidden(true)

            Text("Restaurant Radar")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Restaurants picked by people who eat like you.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 20) {
            featureRow(
                systemImage: "person.2.fill",
                title: "Taste twins",
                detail: "People who eat like you, in any city."
            )
            featureRow(
                systemImage: "text.bubble.fill",
                title: "A reason for every pick",
                detail: "See why each place made your list."
            )
            featureRow(
                systemImage: "location.fill",
                title: "Right now, nearby",
                detail: "Open now, close by, and something new."
            )
        }
    }

    private func featureRow(systemImage: String, title: String, detail: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Brand.accent)
                .frame(width: featureIconSize, height: featureIconSize)
                .background(Brand.accent.opacity(0.15), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            NavigationLink {
                RegisterView()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            NavigationLink {
                LoginView()
            } label: {
                Text("I already have an account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .font(.headline)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .frame(maxWidth: 480)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // A soft brand glow at the top that fades into the normal background (light and dark mode)
    private var warmBackground: some View {
        LinearGradient(
            colors: [Brand.accent.opacity(0.22), Brand.accent.opacity(0)],
            startPoint: .top,
            endPoint: .center
        )
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

#Preview {
    UnauthenticatedView()
}
