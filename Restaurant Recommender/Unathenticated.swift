//
//  Unathenticated.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/21/26.
//

import SwiftUI

struct UnauthenticatedView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.orange)
                Text("Restaurant Radar")
                    .font(.largeTitle)
                    .bold()
                Text("Find your next favorite spot.")
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink(destination: LoginView()) {
                    Text("Log In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                NavigationLink(destination: RegisterView()) {
                    Text("Register")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

#Preview {
    UnauthenticatedView()
}
