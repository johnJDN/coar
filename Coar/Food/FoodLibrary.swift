import Foundation

/// A line that means one of the user's own Food Items or Meals (spec "Your library wins"):
/// logged through it, so the Entry links to it and its numbers are the user's, not a model's.
enum LibraryMatch: Codable, Equatable {
    case foodItem(FoodItemRecord.ID, serving: ServingRecord.ID)
    case meal(MealRecord.ID)
}

/// The user's catalogue as the Describe tab matches lines against it: the unarchived Food
/// Items, and the unarchived Meals that can be logged (a Meal missing a Serving would
/// undercount). A line that is exactly a name matches here, for free; looser wording is left
/// to the model, which sees the catalogue as short handles (`f1`, `s1`, `m1`) instead of ids,
/// and whose answer is resolved back here, so the macros always come from the catalogue.
struct FoodLibrary {

    let foodItems: [FoodItemRecord]
    let meals: [MealRecord]

    init(foodItems: [FoodItemRecord], meals: [MealRecord]) {
        self.foodItems = foodItems.filter { !$0.isArchived && !$0.servings.isEmpty }
        self.meals = meals.filter { !$0.isArchived && $0.isLoggable }
    }

    static let empty = FoodLibrary(foodItems: [], meals: [])

    var isEmpty: Bool {
        foodItems.isEmpty && meals.isEmpty
    }

    // MARK: Exact names

    /// The line when it is a Food Item's or Meal's name, optionally after a quantity ("2 eggs",
    /// "½ overnight oats", "1.5x protein shake"): its default Serving (or the Meal) times that.
    func exactMatch(_ line: String) -> Estimate? {
        let (quantity, name) = Self.leadingQuantity(FoodText.normalised(line))
        let wanted = Self.variants(name)
        if let item = foodItems.first(where: { !Self.variants(FoodText.normalised($0.name)).isDisjoint(with: wanted) }),
           let serving = item.defaultServing {
            return estimate(item, serving, quantity: quantity)
        }
        if let meal = meals.first(where: { !Self.variants(FoodText.normalised($0.name)).isDisjoint(with: wanted) }) {
            return estimate(meal, quantity: quantity)
        }
        return nil
    }

    /// A leading amount and what follows it; 1 and the whole line when there is none.
    static func leadingQuantity(_ normalised: String) -> (Double, String) {
        var words = normalised.split(separator: " ").map(String.init)
        guard words.count > 1, let first = words.first, var amount = number(first.trimmingCharacters(in: CharacterSet(charactersIn: "x×"))), amount > 0 else {
            return (1, normalised)
        }
        words.removeFirst()
        if words.first == "x" || words.first == "×", words.count > 1 {
            words.removeFirst()
        }
        amount = (amount * 100).rounded() / 100
        return (amount, words.joined(separator: " "))
    }

    private static let fractions: [Character: Double] = ["¼": 0.25, "½": 0.5, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3]

    /// "2", "1.5", "1/2", "½", "1½".
    private static func number(_ text: String) -> Double? {
        if let value = Double(text) { return value }
        let parts = text.split(separator: "/")
        if parts.count == 2, let top = Double(parts[0]), let bottom = Double(parts[1]), bottom > 0 { return top / bottom }
        if let last = text.last, let fraction = fractions[last] {
            let whole = text.dropLast()
            if whole.isEmpty { return fraction }
            return Double(whole).map { $0 + fraction }
        }
        return nil
    }

    /// A name with and without a plural ending, so "egg" and "eggs" meet.
    private static func variants(_ name: String) -> Set<String> {
        var names: Set<String> = [name]
        if name.hasSuffix("es") { names.insert(String(name.dropLast(2))) }
        if name.hasSuffix("s") { names.insert(String(name.dropLast())) }
        return names
    }

    // MARK: Handles for the model

    /// The catalogue as the model sees it, or nil when there is none: one line per Food Item
    /// with its Servings, one per Meal.
    var promptListing: String? {
        guard !isEmpty else { return nil }
        let items = foodItems.enumerated().map { index, item in
            let servings = item.servings.enumerated().map { "s\($0.offset + 1) \"\($0.element.name)\"" }.joined(separator: ", ")
            return "f\(index + 1) \(item.name): \(servings)"
        }
        let meals = meals.enumerated().map { "m\($0.offset + 1) \($0.element.name) (meal)" }
        return (items + meals).joined(separator: "\n")
    }

    /// The model's match resolved against the catalogue; nil when a handle is unknown, so the
    /// model's own estimate stands. A missing or unknown Serving means the default one.
    func resolve(food handle: String, serving: String?, quantity: Double) -> Estimate? {
        let quantity = quantity > 0 && quantity.isFinite ? quantity : 1
        if handle.hasPrefix("f"), let index = Int(handle.dropFirst()), foodItems.indices.contains(index - 1) {
            let item = foodItems[index - 1]
            let chosen = serving.flatMap { $0.hasPrefix("s") ? Int($0.dropFirst()) : nil }
                .flatMap { item.servings.indices.contains($0 - 1) ? item.servings[$0 - 1] : nil }
            guard let servingRecord = chosen ?? item.defaultServing else { return nil }
            return estimate(item, servingRecord, quantity: quantity)
        }
        if handle.hasPrefix("m"), let index = Int(handle.dropFirst()), meals.indices.contains(index - 1) {
            return estimate(meals[index - 1], quantity: quantity)
        }
        return nil
    }

    // MARK: Estimates from the catalogue

    private func estimate(_ item: FoodItemRecord, _ serving: ServingRecord, quantity: Double) -> Estimate {
        Estimate(
            name: item.name, quantity: quantity, unit: serving.name, grams: serving.grams.map { $0 * quantity },
            macros: serving.macros.scaled(by: quantity), source: .food, assumption: "",
            match: .foodItem(item.id, serving: serving.id)
        )
    }

    private func estimate(_ meal: MealRecord, quantity: Double) -> Estimate {
        Estimate(
            name: meal.name, quantity: quantity, unit: EntryRecord.mealServingName, grams: nil,
            macros: meal.macros.scaled(by: quantity), source: .meal, assumption: "",
            match: .meal(meal.id)
        )
    }
}
