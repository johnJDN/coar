import Foundation

/// One of exactly four tracked nutrition values (CONTEXT.md "Macro"). Calories in kcal;
/// protein, fat, and carbs in grams.
enum Macro: CaseIterable {
    case calories, protein, fat, carbs

    var title: String {
        switch self {
        case .calories: return "Calories"
        case .protein: return "Protein"
        case .fat: return "Fat"
        case .carbs: return "Carbs"
        }
    }

    var unit: String {
        self == .calories ? "kcal" : "g"
    }

    var keyPath: WritableKeyPath<Macros, Double> {
        switch self {
        case .calories: return \.calories
        case .protein: return \.protein
        case .fat: return \.fat
        case .carbs: return \.carbs
        }
    }
}

/// The four Macro values together, as a Target holds them.
struct Macros: Hashable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double

    subscript(macro: Macro) -> Double {
        get { self[keyPath: macro.keyPath] }
        set { self[keyPath: macro.keyPath] = newValue }
    }
}
