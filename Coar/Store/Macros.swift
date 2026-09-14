import Foundation

/// The four tracked nutrition values, and nothing else (CONTEXT.md "Macro"). Calories in
/// kcal; protein, fat, and carbs in grams.
struct Macros: Hashable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
}
