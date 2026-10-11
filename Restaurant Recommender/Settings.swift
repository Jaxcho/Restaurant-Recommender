//
//  Settings.swift
//  Restaurant Recommender
//
//  Settings saved on this phone with @AppStorage. Only UI preferences go
//  here; tokens stay in the Keychain.
//

import SwiftUI

enum SettingsKey {
    static let askCravingsOnLaunch = "askCravingsOnLaunch"
    static let appearance = "appearance"
}

/// Light or dark mode for the app; `.system` follows the phone.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// nil means "follow the phone"
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
