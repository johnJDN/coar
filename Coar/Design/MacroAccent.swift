import SwiftUI
import UIKit

// One accent per metric, used everywhere that metric appears (DESIGN.md §3): protein blue,
// carbs orange, fat pink. Calories has no metric accent; amber is its tile colour.
extension Macro {
    var uiAccent: UIColor {
        switch self {
        case .calories: return UIColor.accentAmber
        case .protein: return UIColor.accentBlue
        case .fat: return UIColor.accentPink
        case .carbs: return UIColor.accentOrange
        }
    }

    var accent: Color { Color(uiColor: uiAccent) }

    var systemImage: String {
        switch self {
        case .calories: return "flame.fill"
        case .protein: return "fish.fill"
        case .fat: return "drop.fill"
        case .carbs: return "leaf.fill"
        }
    }

    /// The gram macros' one-letter form in a compact line: "P 12 · F 10 · C 0".
    var letter: String {
        switch self {
        case .calories: return "kcal"
        case .protein: return "P"
        case .fat: return "F"
        case .carbs: return "C"
        }
    }
}
