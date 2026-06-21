//
//  AppEnvironment.swift
//  Restaurant Recommender
//
//  Created by Jax Choi on 6/14/26.
//

import Foundation

private let coderSchool: Int = 44;

enum AppEnvironment {
    #if targetEnvironment(simulator)
    static let apiBaseURL = URL(string: "http://127.0.0.1:8000")!
    #else
    static let apiBaseURL = URL(string: "http://192.168.86.\(coderSchool):8000")!
    #endif
}
