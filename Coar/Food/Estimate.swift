import Foundation

/// An Estimate (CONTEXT.md): the name, portion, and macros given for a food the user described
/// or photographed, before it is logged. Logging it makes an Entry, which keeps its own copy
/// (ADR 0003) and nothing else of the Estimate: where the numbers came from shows only here.
struct Estimate: Equatable {

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
    /// Fiber, sodium, caffeine, and alcohol for the whole portion, only those the source
    /// knew (CONTEXT.md "Extra"); never guessed for a brand or restaurant food.
    var extras = Extras()
    /// The food's natural serving and its weight, apart from how much was eaten ("5 crackers",
    /// 16 g); what Save to Foods keeps (`naturalServings`).
    var servingSize: ServingSize? = nil

    /// "2 × large egg".
    var portion: String {
        FoodText.quantity(quantity, of: unit)
    }
}

// MARK: - Saved drafts and the line cache

/// Read with a missing field taking its default, so the Describe draft and the estimate cache
/// saved by an older build still load (a new field must never cost the user a draft).
extension Estimate: Codable {

    private enum CodingKeys: String, CodingKey {
        case name, quantity, unit, grams, macros, source, assumption, needsLookup, match, extras, servingSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(Double.self, forKey: .quantity)
        unit = try container.decode(String.self, forKey: .unit)
        grams = try container.decodeIfPresent(Double.self, forKey: .grams)
        macros = try container.decode(Macros.self, forKey: .macros)
        source = try container.decode(Source.self, forKey: .source)
        assumption = try container.decode(String.self, forKey: .assumption)
        needsLookup = try container.decodeIfPresent(Bool.self, forKey: .needsLookup) ?? false
        match = try container.decodeIfPresent(LibraryMatch.self, forKey: .match)
        extras = try container.decodeIfPresent(Extras.self, forKey: .extras) ?? Extras()
        servingSize = try container.decodeIfPresent(ServingSize.self, forKey: .servingSize)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
        try container.encodeIfPresent(grams, forKey: .grams)
        try container.encode(macros, forKey: .macros)
        try container.encode(source, forKey: .source)
        try container.encode(assumption, forKey: .assumption)
        try container.encode(needsLookup, forKey: .needsLookup)
        try container.encodeIfPresent(match, forKey: .match)
        if !extras.isEmpty { try container.encode(extras, forKey: .extras) }
        try container.encodeIfPresent(servingSize, forKey: .servingSize)
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
        if macros.calories > Self.maximumCalories { return "Over 5,000 cal came back, which can't be right." }
        if let grams, grams > Self.maximumGrams { return "Over 3 kg came back, which can't be right." }
        return nil
    }

    /// Looked up with protein, fat, and carbs all 0: a diet drink, or a lookup that found
    /// nothing and sent its template's 0s back. Never cached, so it is always asked again.
    var isLookupWithoutMacros: Bool {
        source == .lookedUp && macros.protein == 0 && macros.fat == 0 && macros.carbs == 0
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
        /// The line listed separate foods ("eggs, toast and coffee"): each as its own line,
        /// as the model wrote it, for the Describe tab to split into.
        case severalFoods([String])
    }

    /// A model's pick from the user's catalogue, by handle (`FoodLibrary.promptListing`).
    struct ModelMatch: Decodable, Equatable {
        let food: String
        let serving: String?
        let quantity: Double
    }

    /// The items in a photo reply (`FoodPhotoPrompt.schema`), each with the model's pick from
    /// the catalogue when it named one. An empty list is a photo with no food in it.
    static func photoItems(reply: Data) throws -> [(estimate: Estimate, match: ModelMatch?)] {
        struct Reply: Decodable {
            struct Item: Decodable {
                let source: String
                let name: String
                let quantity: Double
                let unit: String
                let grams: Double?
                let calories: Double
                let protein: Double
                let fat: Double
                let carbs: Double
                let assumption: String?
                let match: ModelMatch?
                let fiber_g: Double?
                let sodium_mg: Double?
                let caffeine_mg: Double?
                let alcohol_drinks: Double?
                let serving_name: String?
                let serving_grams: Double?
                let piece_name: String?
            }
            let items: [Item]
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: reply) else { throw ReplyError.unreadable }
        return reply.items.map { item in
            let unit = item.unit.trimmingCharacters(in: .whitespaces)
            let estimate = Estimate(
                name: item.name.trimmingCharacters(in: .whitespaces),
                quantity: item.quantity > 0 ? item.quantity : 1,
                unit: unit.isEmpty ? "serving" : unit,
                grams: item.grams.flatMap { $0 > 0 ? $0 : nil },
                macros: Macros(calories: item.calories, protein: item.protein, fat: item.fat, carbs: item.carbs),
                source: item.source == "label" ? .label : .photo,
                assumption: item.assumption?.trimmingCharacters(in: .whitespaces) ?? "",
                extras: Extras(fiber: item.fiber_g, sodium: item.sodium_mg, caffeine: item.caffeine_mg, alcohol: item.alcohol_drinks).normalised(),
                servingSize: ServingSize(reply: item.serving_name, grams: item.serving_grams, piece: item.piece_name)
            )
            return (estimate, item.match)
        }
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
            let fiber_g: Double?
            let sodium_mg: Double?
            let caffeine_mg: Double?
            let alcohol_drinks: Double?
            let parts: [String]?
            let serving_name: String?
            let serving_grams: Double?
            let piece_name: String?
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: reply) else { throw ReplyError.unreadable }
        guard reply.is_food else { throw ReplyError.notFood }
        let parts = (reply.parts ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if parts.count > 1 { throw ReplyError.severalFoods(parts) }
        let unit = reply.unit.trimmingCharacters(in: .whitespaces)
        let estimate = Estimate(
            name: reply.name.trimmingCharacters(in: .whitespaces),
            quantity: reply.quantity,
            unit: unit.isEmpty ? "serving" : unit,
            grams: reply.grams.flatMap { $0 > 0 ? $0 : nil },
            macros: Macros(calories: reply.calories, protein: reply.protein, fat: reply.fat, carbs: reply.carbs),
            source: source,
            assumption: reply.assumption?.trimmingCharacters(in: .whitespaces) ?? "",
            needsLookup: reply.needs_lookup ?? false,
            extras: Extras(fiber: reply.fiber_g, sodium: reply.sodium_mg, caffeine: reply.caffeine_mg, alcohol: reply.alcohol_drinks).normalised(),
            servingSize: ServingSize(reply: reply.serving_name, grams: reply.serving_grams, piece: reply.piece_name)
        )
        return (estimate, reply.match)
    }
}

/// A food's natural serving as a person counts it, with its weight ("5 crackers", 16 g;
/// "1 breast", 172 g), and one piece when it counts several ("cracker").
struct ServingSize: Codable, Equatable {
    var name: String
    var grams: Double
    var piece: String?

    init(name: String, grams: Double, piece: String? = nil) {
        self.name = name
        self.grams = grams
        self.piece = piece
    }

    /// From a reply's fields; nil without a name or a weight.
    init?(reply name: String?, grams: Double?, piece: String?) {
        // A model sometimes writes "None" or a bare weight where it has no serving.
        func meaningful(_ text: String?) -> String {
            let trimmed = text?.trimmingCharacters(in: .whitespaces) ?? ""
            return ["none", "null", "n/a", "na", "-"].contains(trimmed.lowercased()) ? "" : trimmed
        }
        let name = meaningful(name)
        guard !name.isEmpty, PortionUnit.grams(inOne: name) == nil, let grams, grams > 0, grams.isFinite else { return nil }
        let piece = meaningful(piece)
        self.init(name: name, grams: grams, piece: piece.isEmpty ? nil : piece)
    }

    /// How many pieces the serving is: 5 for "5 crackers", 15 for "about 15 chips"; nil for
    /// "2/3 cup"-like servings that aren't counted in pieces.
    var pieceCount: Double? {
        guard piece != nil else { return nil }
        let words = name.lowercased().split(separator: " ").map(String.init).filter { !["about", "approx", "approx.", "around", "~"].contains($0) }
        return words.first.flatMap(FoodText.parseAmount)
    }
}

extension Estimate {

    /// What Save to Foods keeps when the food's natural serving is known: that serving with its
    /// weight (the default), and one piece when it counts several, each scaled from what was
    /// eaten by weight. Nil without a natural serving or without the line's weight to scale by.
    var naturalServings: [ServingDraft]? {
        guard let size = servingSize else { return nil }
        let lineGrams = grams ?? PortionUnit.gramsPer[unit.lowercased()].map { $0 * quantity }
        guard let lineGrams, lineGrams > 0 else { return nil }
        let share = size.grams / lineGrams
        let serving = ServingDraft(name: size.name, macros: macros.scaled(by: share), grams: size.grams, isDefault: true, extras: extras.scaled(by: share))
        var servings = [serving]
        if let piece = size.piece, let count = size.pieceCount, count > 1, piece.lowercased() != size.name.lowercased() {
            servings.append(ServingDraft(name: piece, macros: serving.macros.scaled(by: 1 / count), grams: size.grams / count, extras: serving.extras.scaled(by: 1 / count)))
        }
        return servings
    }
}
