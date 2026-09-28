import Foundation

/// An Estimate (CONTEXT.md): the name, portion, and macros given for a food the user described
/// or photographed, before it is logged. Logging it makes an Entry, which keeps its own copy
/// (ADR 0003) and nothing else of the Estimate: where the numbers came from shows only here.
struct Estimate: Equatable, Codable {

    /// Where the numbers came from, shown beside them so the user knows which to check.
    enum Source: String, Codable {
        case estimated, lookedUp, photo, label, typed
        /// One of the user's own Food Items or Meals.
        case food, meal

        var title: String {
            switch self {
            case .food: return "Your food"
            case .meal: return "Your meal"
            case .estimated: return "Estimated"
            case .lookedUp: return "Looked up"
            case .photo: return "From photo"
            case .label: return "From label"
            case .typed: return "Typed"
            }
        }
    }

    /// What the food is, without the amount: "Toast with butter".
    var name: String
    /// How many of `unit` were eaten: 2 (large egg), 150 (g).
    var quantity: Double
    /// One of the portion, singular: "large egg", "slice", "g". Becomes the Entry's Serving name.
    var unit: String
    /// The whole portion's weight, when known.
    var grams: Double?
    /// The four macros for the whole portion.
    var macros: Macros
    var source: Source
    /// What was assumed, in one sentence; empty when nothing was.
    var assumption: String
    /// The model thinks a published figure (a chain, a brand) would beat its estimate.
    var needsLookup = false
    /// The Food Item or Meal this is, when it is one of the user's: logged through it.
    var match: LibraryMatch?

    /// "2 × large egg".
    var portion: String {
        FoodText.quantity(quantity, of: unit)
    }
}

// MARK: - Checks

extension Estimate {

    /// The largest single line Coar accepts; above it the numbers are wrong, not a big meal.
    static let maximumCalories: Double = 5_000
    static let maximumGrams: Double = 3_000

    /// Why the numbers cannot be logged as they are, or nil when they can: never logged
    /// quietly wrong (DESIGN.md: errors are stated).
    var impossibility: String? {
        let numbers = [quantity, macros.calories, macros.protein, macros.fat, macros.carbs] + (grams.map { [$0] } ?? [])
        if numbers.contains(where: { !$0.isFinite || $0 < 0 }) { return "Impossible numbers came back." }
        if quantity == 0 { return "No amount came back." }
        if macros.calories > Self.maximumCalories { return "Over 5,000 kcal came back, which can't be right." }
        if let grams, grams > Self.maximumGrams { return "Over 3 kg came back, which can't be right." }
        return nil
    }

    /// The calories disagree with what the three macros add up to (4 kcal per gram of protein
    /// and carbs, 9 per gram of fat) by more than 40 kcal and 20%: worth a look, not a block.
    var caloriesDisagree: Bool {
        let fromMacros = 4 * macros.protein + 4 * macros.carbs + 9 * macros.fat
        return abs(macros.calories - fromMacros) > max(40, 0.2 * macros.calories)
    }
}

// MARK: - Reading a model's reply

extension Estimate {

    enum ReplyError: Error, Equatable {
        /// The line was not something eaten or drunk.
        case notFood
        /// The reply was not the agreed JSON.
        case unreadable
    }

    /// A model's pick from the user's catalogue, by handle (`FoodLibrary.promptListing`).
    struct ModelMatch: Decodable, Equatable {
        let food: String
        let serving: String?
        let quantity: Double
    }

    /// The Estimate in a model's JSON reply (the shape `FoodEstimatePrompt.schema` asks for).
    init(reply: Data, source: Source) throws {
        self = try Self.parse(reply: reply, source: source).estimate
    }

    /// The Estimate in a model's reply and, when it named one, its pick from the catalogue.
    static func parse(reply: Data, source: Source) throws -> (estimate: Estimate, match: ModelMatch?) {
        struct Reply: Decodable {
            let is_food: Bool
            let name: String
            let quantity: Double
            let unit: String
            let grams: Double?
            let calories: Double
            let protein: Double
            let fat: Double
            let carbs: Double
            let needs_lookup: Bool?
            let assumption: String?
            let match: ModelMatch?
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: reply) else { throw ReplyError.unreadable }
        guard reply.is_food else { throw ReplyError.notFood }
        let unit = reply.unit.trimmingCharacters(in: .whitespaces)
        let estimate = Estimate(
            name: reply.name.trimmingCharacters(in: .whitespaces),
            quantity: reply.quantity,
            unit: unit.isEmpty ? "serving" : unit,
            grams: reply.grams.flatMap { $0 > 0 ? $0 : nil },
            macros: Macros(calories: reply.calories, protein: reply.protein, fat: reply.fat, carbs: reply.carbs),
            source: source,
            assumption: reply.assumption?.trimmingCharacters(in: .whitespaces) ?? "",
            needsLookup: reply.needs_lookup ?? false
        )
        return (estimate, reply.match)
    }
}
