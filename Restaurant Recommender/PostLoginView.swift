//
//  PostLoginView.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/20/26.
//
import SwiftUI

struct PostLoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var errorMessage: String? = nil
    
    func logout(){
        Task {
            defer {
              
            }
            
            await authManager.logout()
           
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Button("Logout"){
                    logout()
                }
                
                Text("Welcome!")
                    .font(.title)
                NavigationLink(destination: LocationView() ){
                    Text("Go to locations")
                }
                NavigationLink(destination: ShowVisited() ){
                    Text("See visited")
                }
                               
            }
            .padding()
        }
    }
}


