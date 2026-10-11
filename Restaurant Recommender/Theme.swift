//
//  Theme.swift
//  Restaurant Recommender
//
//  The shared look: brand colors, cuisine emoji and labels, tag chips and the card style.
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

    static func of(_ key: String?) -> CuisineStyle {
        switch key {
        case "american": CuisineStyle(emoji: "🍔", label: "American")
        case "chinese": CuisineStyle(emoji: "🥟", label: "Chinese")
        case "japanese": CuisineStyle(emoji: "🍣", label: "Japanese")
        case "korean": CuisineStyle(emoji: "🍲", label: "Korean")
        case "southeast_asian": CuisineStyle(emoji: "🍜", label: "Southeast Asian")
        case "indian": CuisineStyle(emoji: "🍛", label: "Indian")
        case "latin": CuisineStyle(emoji: "🌮", label: "Mexican & Latin")
        case "italian": CuisineStyle(emoji: "🍕", label: "Italian & Pizza")
        case "mediterranean": CuisineStyle(emoji: "🥙", label: "Mediterranean")
        case "brunch": CuisineStyle(emoji: "🥞", label: "Breakfast & Brunch")
        case "fast_food": CuisineStyle(emoji: "🍟", label: "Fast Food")
        case "seafood": CuisineStyle(emoji: "🦞", label: "Seafood")
        case "vegetarian": CuisineStyle(emoji: "🥗", label: "Vegetarian")
        default: CuisineStyle(emoji: "🍽️", label: "Restaurant")
        }
    }
}

/// A cuisine's emoji on a plain rounded tile, used as the leading icon on restaurant rows.
/// Every cuisine gets the same neutral tile so the emoji is the only color.
struct CuisineBadge: View {
    let cuisine: String?
    var size: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Text(CuisineStyle.of(cuisine).emoji)
            .font(.system(size: size * scale * 0.45))
            .frame(width: size * scale, height: size * scale)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: size * scale * 0.28, style: .continuous))
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
