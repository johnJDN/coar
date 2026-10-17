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
        if let byWeight = weightMatch(line) { return byWeight }
        let normalised = FoodText.normalised(line)
        let (quantity, name) = Self.leadingQuantity(normalised)
        let wanted = Self.variants(name)
        if let item = foodItems.first(where: { !Self.variants(FoodText.normalised($0.name)).isDisjoint(with: wanted) }),
           let serving = item.defaultServing {
            // "8 ritz crackers" against "5 crackers" and "cracker": a count means pieces.
            if name != normalised, let piece = Self.pieceServing(of: item) {
                return estimate(item, piece, quantity: quantity)
            }
            return estimate(item, serving, quantity: quantity)
        }
        if let meal = meals.first(where: { !Self.variants(FoodText.normalised($0.name)).isDisjoint(with: wanted) }) {
            return estimate(meal, quantity: quantity)
        }
        return nil
    }

    /// The one-piece Serving of a food whose default counts several ("cracker" beside "5
    /// crackers"): a Serving with no number in its name, while the default starts with one
    /// above 1.
    static func pieceServing(of item: FoodItemRecord) -> ServingRecord? {
        guard let main = item.defaultServing,
              let count = main.name.split(separator: " ").first.flatMap({ FoodText.parseAmount(String($0)) }), count > 1 else { return nil }
        return item.servings.first { $0.id != main.id && !$0.name.contains(where: \.isNumber) }
    }

    // MARK: Grams of a saved food

    /// "45g granola", "45 grams of granola", "granola 45 g": a saved food by its name and a
    /// weight in grams, worked out from a Serving whose weight is known (the label's), with no
    /// model. Logged in grams.
    func weightMatch(_ line: String) -> Estimate? {
        guard let (grams, name) = Self.weightAndName(FoodText.normalised(line)), grams > 0 else { return nil }
        let wanted = Self.variants(name)
        guard let item = foodItems.first(where: { !Self.variants(FoodText.normalised($0.name)).isDisjoint(with: wanted) }),
              let serving = ([item.defaultServing].compactMap { $0 } + item.servings).first(where: { ($0.grams ?? 0) > 0 }),
              let weight = serving.grams else { return nil }
        let share = grams / weight
        return Estimate(
            name: item.name, quantity: grams, unit: "g", grams: grams,
            macros: serving.macros.scaled(by: share), source: .food, assumption: "",
            match: .foodItem(item.id, serving: serving.id),
            extras: serving.extras.scaled(by: share)
        )
    }

    /// A weight in grams before or after the name: "45g granola", "45 g of granola",
    /// "granola, 45 grams".
    static func weightAndName(_ normalised: String) -> (Double, String)? {
        let unit = #"(?:g|gr|gram|grams)"#
        let patterns = [#"^(\d+(?:\.\d+)?)\s*\#(unit)\s+(?:of\s+)?(.+)$"#, #"^(.+?),?\s+(\d+(?:\.\d+)?)\s*\#(unit)$"#]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: normalised, range: NSRange(normalised.startIndex..., in: normalised)),
                  let first = Range(match.range(at: 1), in: normalised), let second = Range(match.range(at: 2), in: normalised) else { continue }
            let (number, name) = index == 0 ? (normalised[first], normalised[second]) : (normalised[second], normalised[first])
            guard let grams = Double(number) else { continue }
            return (grams, name.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    // MARK: Suggestions while typing

    /// One of the user's foods or meals offered above the keyboard as a line is typed.
    struct Suggestion: Equatable {
        /// What the line becomes when it is picked: the name, after the amount typed if any
        /// ("2 Pho"), so it matches exactly and fills in with no model.
        let text: String
        let name: String
        /// "bowl · 450 cal", or "meal · 620 cal".
        let detail: String
    }

    /// The saved foods and meals whose name the line (after any amount) starts, or a word of it
    /// starts: names starting with it first, each group in the catalogue's order (most recently
    /// used first). Nothing for under two letters, or when the line already is a name.
    func suggestions(for line: String, limit: Int = 4) -> [Suggestion] {
        let normalised = FoodText.normalised(line)
        let (quantity, typed) = Self.leadingQuantity(normalised)
        guard typed.count >= 2, exactMatch(line) == nil else { return [] }
        let prefix = quantity == 1 && typed == normalised ? "" : "\(FoodText.amount(quantity)) "

        var candidates: [(name: String, detail: String)] = foodItems.compactMap { item in
            item.defaultServing.map { (item.name, "\($0.name) · \(FoodText.calories($0.macros))") }
        }
        candidates += meals.map { ($0.name, "meal · \(FoodText.calories($0.macros))") }

        func rank(_ name: String) -> Int? {
            let key = FoodText.normalised(name)
            if key.hasPrefix(typed) { return 0 }
            if key.split(separator: " ").contains(where: { $0.hasPrefix(typed) }) { return 1 }
            return nil
        }
        return candidates
            .enumerated()
            .compactMap { index, candidate in rank(candidate.name).map { (rank: $0, index: index, candidate: candidate) } }
            .sorted { ($0.rank, $0.index) < ($1.rank, $1.index) }
            .prefix(limit)
            .map { Suggestion(text: prefix + $0.candidate.name, name: $0.candidate.name, detail: $0.candidate.detail) }
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

    /// "2", "1.5", "1/2", "½", "1½".
    private static func number(_ text: String) -> Double? {
        FoodText.parseAmount(text)
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
            // A Serving's weight, when known and not already in its name, so "45 g of it" can be
            // worked out against it.
            let servings = item.servings.enumerated().map { offset, serving in
                let weight = serving.grams.flatMap { grams in serving.name.contains(" g") || serving.name.hasSuffix("g)") ? nil : " (\(FoodText.amount(grams)) g)" } ?? ""
                return "s\(offset + 1) \"\(serving.name)\"\(weight)"
            }.joined(separator: ", ")
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
            match: .foodItem(item.id, serving: serving.id),
            extras: serving.extras.scaled(by: quantity)
        )
    }

    private func estimate(_ meal: MealRecord, quantity: Double) -> Estimate {
        Estimate(
            name: meal.name, quantity: quantity, unit: EntryRecord.mealServingName, grams: nil,
            macros: meal.macros.scaled(by: quantity), source: .meal, assumption: "",
            match: .meal(meal.id),
            extras: meal.extras.scaled(by: quantity)
        )
    }
}
