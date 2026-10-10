//
//  Theme.swift
//  Restaurant Recommender
//
//  The shared look: brand colors, cuisine emoji, tag chips and the card style.
//  The brand orange itself is AccentColor in the asset catalog, so `.tint` and
//  `Color.accentColor` already use it everywhere.
//

import SwiftUI

enum Brand {
    static let accent = Color.accentColor
    static let wildcard = Color.purple
    static let open = Color.green
    static let closed = Color.red
    static let star = Color.yellow
}

/// How a cuisine key from the backend (see API/cuisines.py) is shown in the app.
struct CuisineStyle {
    let emoji: String
    let label: String
    let tint: Color

    static func of(_ key: String?) -> CuisineStyle {
        switch key {
        case "american": CuisineStyle(emoji: "🍔", label: "American", tint: .red)
        case "chinese": CuisineStyle(emoji: "🥟", label: "Chinese", tint: .orange)
        case "japanese": CuisineStyle(emoji: "🍣", label: "Japanese", tint: .pink)
        case "korean": CuisineStyle(emoji: "🍲", label: "Korean", tint: .purple)
        case "southeast_asian": CuisineStyle(emoji: "🍜", label: "Southeast Asian", tint: .teal)
        case "indian": CuisineStyle(emoji: "🍛", label: "Indian", tint: .yellow)
        case "latin": CuisineStyle(emoji: "🌮", label: "Mexican & Latin", tint: .green)
        case "italian": CuisineStyle(emoji: "🍕", label: "Italian & Pizza", tint: .mint)
        case "mediterranean": CuisineStyle(emoji: "🥙", label: "Mediterranean", tint: .cyan)
        case "brunch": CuisineStyle(emoji: "🥞", label: "Breakfast & Brunch", tint: .yellow)
        case "fast_food": CuisineStyle(emoji: "🍟", label: "Fast Food", tint: .orange)
        case "seafood": CuisineStyle(emoji: "🦞", label: "Seafood", tint: .blue)
        case "vegetarian": CuisineStyle(emoji: "🥗", label: "Vegetarian", tint: .green)
        default: CuisineStyle(emoji: "🍽️", label: "Restaurant", tint: Brand.accent)
        }
    }
}

/// A cuisine's emoji in a soft tinted circle, used as the leading icon on restaurant rows.
struct CuisineBadge: View {
    let cuisine: String?
    var size: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let style = CuisineStyle.of(cuisine)
        Text(style.emoji)
            .font(.system(size: size * scale * 0.5))
            .frame(width: size * scale, height: size * scale)
            .background(style.tint.opacity(0.15), in: Circle())
            .accessibilityHidden(true)
    }
}

/// A small rounded chip such as "Open now", "Wildcard" or a cuisine name.
struct TagLabel: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = Brand.accent

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            Text(text)
                .foregroundStyle(.primary)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

extension View {
    /// The rounded card used for grouped content on screens and sheets.
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
