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

extension Macros {
    static let zero = Macros(calories: 0, protein: 0, fat: 0, carbs: 0)

    /// The four values as typed into a form: an empty field is 0; a negative or non-finite
    /// value makes the whole thing invalid.
    init?(typed fields: [Macro: Double?]) {
        self = .zero
        for macro in Macro.allCases {
            let value = (fields[macro] ?? nil) ?? 0
            guard value >= 0, value.isFinite else { return nil }
            self[macro] = value
        }
    }

    /// The four values added up; zero for nothing.
    static func sum(_ all: [Macros]) -> Macros {
        all.reduce(.zero) { total, next in
            Macros(calories: total.calories + next.calories, protein: total.protein + next.protein, fat: total.fat + next.fat, carbs: total.carbs + next.carbs)
        }
    }

    /// The macros for `quantity` of something whose macros for one are `self`.
    func scaled(by quantity: Double) -> Macros {
        Macros(calories: calories * quantity, protein: protein * quantity, fat: fat * quantity, carbs: carbs * quantity)
    }
}
