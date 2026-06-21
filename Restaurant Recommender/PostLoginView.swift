//
//  PostLoginView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI

struct PostLoginView: View {
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Welcome!")
                    .font(.title)
                NavigationLink(destination: LocationView()) {
                    Text("Go to locations")
                }
            }
            .padding()
        }
    }
}

#Preview {
    PostLoginView()
}
