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
                Text("Hello, World!")
                NavigationLink(destination: RegisterView()) {
                    Text("Register")
                }
                NavigationLink(destination: LoginView()) {
                    Text("Login")
                }
            }
        }
    }
}
