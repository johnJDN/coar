import SwiftUI

// One accent per metric, used everywhere that metric appears (DESIGN.md §3): protein blue,
// carbs orange, fat pink. Calories has no metric accent; amber is its tile colour.
extension Macro {
    var accent: Color {
        switch self {
        case .calories: return Color.accentAmber
        case .protein: return Color.accentBlue
        case .fat: return Color.accentPink
        case .carbs: return Color.accentOrange
        }
    }

    var systemImage: String {
        switch self {
        case .calories: return "flame.fill"
        case .protein: return "fish.fill"
        case .fat: return "drop.fill"
        case .carbs: return "leaf.fill"
        }
    }
}
