import Foundation
import os

/// Turns one line the user typed into an Estimate (`.scratch/ai-food-logging/spec.md`,
/// "Estimating, cheapest first"), matching the user's catalogue when the line means one of
/// its foods. Throws an `OpenRouterError` when the request fails, or an
/// `Estimate.ReplyError` when the reply is not a food.
protocol FoodEstimator {
    func estimate(_ line: String, library: FoodLibrary) async throws -> Estimate
    /// Every food in a photo, or the one food a nutrition label is for (ticket 07); none when
    /// the photo shows neither. `jpeg` is sent and never kept. `note` is what the user said
    /// about it ("I ate half"), sent with it; nil for none.
    func estimate(photo jpeg: Data, note: String?, library: FoodLibrary) async throws -> [Estimate]
}

/// The models, one constant each, so swapping one is a one-line change (ADR 0007).
enum FoodModels {
    /// Everyday foods, typed: cheap and quick, with strict JSON.
    static let text = "google/gemini-3.5-flash-lite"
    /// Restaurant and brand foods: reads Exa's top web results for the published numbers,
    /// with strict JSON. Chosen over Sonar and five others by `lookup-test.md` (2026-10-03):
    /// right 24 times in 26, never wrong, and both made-up flavours refused every time.
    static let lookup = "google/gemini-3.5-flash-lite"
    /// Exa always searches; Gemini's own Google search is its choice, and it never chose to.
    static let lookupSearch = OpenRouterClient.WebSearch(engine: "exa", maxResults: 5)
    /// Photos of meals and nutrition labels: sees images, with strict JSON.
    static let photo = "google/gemini-3.8-flash"
}

/// The four Extras the models are asked for beside the macros (CONTEXT.md "Extra"), worded
/// once for the text, photo, and lookup prompts: a number only where the model can stand
/// behind it, null otherwise, so nothing guessed is shown as a reading.
enum FoodExtrasPrompt {

    static let rules = """
    - fiber_g, sodium_mg, caffeine_mg and alcohol_drinks: for the whole portion, or null when you don't know them. Give a number only where you can stand behind it: a plain whole food you know well (an egg, a banana, rice) or a published figure. For a restaurant, brand or mixed dish you are unsure of, use null, not a guess.
    - fiber_g in grams and sodium_mg in milligrams; 0 is a real value for a food with none.
    - caffeine_mg in milligrams (coffee, tea, cola, energy drinks, chocolate); null when there is none or you don't know.
    - alcohol_drinks in US standard drinks of 14 g pure alcohol (a 12 oz beer at 5%, 5 oz of wine at 12%, and 1.5 oz of 40% spirits are one each); null when there is none or you don't know. Name the strength you assumed in the assumption.
    """

    /// The four fields' place in a strict schema: a number, or null.
    static let properties: [String: Any] = [
        "fiber_g": ["type": ["number", "null"]],
        "sodium_mg": ["type": ["number", "null"]],
        "caffeine_mg": ["type": ["number", "null"]],
        "alcohol_drinks": ["type": ["number", "null"]],
    ]
    static let required = ["fiber_g", "sodium_mg", "caffeine_mg", "alcohol_drinks"]
}

/// What the text model is told, and the JSON it must reply with. Every field is required
/// (strict schemas allow no optional ones); `grams` is null when unknown.
enum FoodEstimatePrompt {

    static let system = """
    You estimate the nutrition of one food someone ate, described in a single line of a food log.

    Rules:
    - One line is one food as eaten, even if it has parts ("toast with butter" is one food).
    - Give macros for the whole portion described. If no amount is given, assume one typical serving and say what you assumed.
    - Use every detail the line gives: counts of each ingredient, a stated weight ("about 450 g before broth"), how much broth or sauce was had, a share of something shared ("split a pizza with 2 friends" is a third), "most of" (about three quarters). When the line counts what went into a dish, add those up rather than estimating a typical dish, and say what you assumed for anything not given (the broth, the oil).
    - name: what the food is, short and capitalised, without the amount ("Toast with butter", "Eggs").
    - quantity and unit: the portion as the person counts it. The unit is singular and describes one ("large egg", "slice", "cup", "g"). "2 eggs" is quantity 2, unit "large egg". "150g chicken" is quantity 150, unit "g".
    - grams: the whole portion's weight in grams if you can reasonably tell, else null.
    - calories in kcal; protein, fat and carbs in grams; all for the whole portion.
    - needs_lookup: true only when the line names a restaurant chain, a brand, or a packaged product whose published nutrition would be more accurate than an estimate. Otherwise false.
    - assumption: one short sentence on what you assumed, or "" if nothing.
    - is_food: false only if the line cannot be something eaten or drunk (a sentence that isn't a food, an activity, a medicine, a vape); then the numbers are 0. This is a food log: when a name could be a food or something else ("Built Puff bar" is a protein bar, not a Puff Bar vape), it's the food.
    - match: null, unless a list of the person's saved foods follows.
    - parts: when the line lists separate foods eaten together ("eggs, toast and coffee", "burger and fries", "2 eggs + bacon"), each food as its own short line with its amount, as the person wrote it ("2 eggs", "toast", "coffee"); otherwise []. One food with parts is one food: "toast with butter", "chicken burrito bowl", "coffee with milk", "pho with extra noodles" are []. So is a dish listed with its ingredients: "malatang bowl with tomato broth, 4 shrimp, 4 slices of beef", "salad with chicken, avocado and ranch", "burrito with rice, beans and steak" are []. When parts has two or more, fill the other fields for the whole line anyway.
    \(FoodExtrasPrompt.rules)
    """

    /// The catalogue section, added after the rules when the user has saved foods.
    static func library(_ listing: String) -> String {
        """

        The person's saved foods and meals, by handle. If the line clearly means one of them, set match: food is its handle, serving is the handle of the serving that fits what they said (null for a meal, or when they don't say), and quantity is how many of that serving (or of the meal). Match only when it is the same food as saved: not when the line adds something the saved food doesn't include ("with milk", "and fries", "with extra noodles"); an addition is not a size. If the line asks for a size and one of the servings is named for that size ("large" for "large fries"), use that serving, quantity 1. Only if none is ("large pho" against a single "bowl", "half a sandwich"), still match it, with quantity scaled from the serving that fits: large about 1.5, small about 0.75, half 0.5, double 2. A product's standard size is not a portion size: "2 large eggs" against a "1 egg" serving is quantity 2. Otherwise match is null. Fill in the estimate fields either way.
        \(listing)
        """
    }

    static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["is_food", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "needs_lookup", "assumption", "match", "parts"] + FoodExtrasPrompt.required,
        "properties": ([
            "is_food": ["type": "boolean"],
            "parts": ["type": "array", "items": ["type": "string"]],
            "name": ["type": "string"],
            "quantity": ["type": "number"],
            "unit": ["type": "string"],
            "grams": ["type": ["number", "null"]],
            "calories": ["type": "number"],
            "protein": ["type": "number"],
            "fat": ["type": "number"],
            "carbs": ["type": "number"],
            "needs_lookup": ["type": "boolean"],
            "assumption": ["type": "string"],
            "match": ["anyOf": [
                ["type": "null"],
                [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["food", "serving", "quantity"],
                    "properties": [
                        "food": ["type": "string"],
                        "serving": ["type": ["string", "null"]],
                        "quantity": ["type": "number"],
                    ],
                ] as [String: Any],
            ]],
        ] as [String: Any]).merging(FoodExtrasPrompt.properties) { first, _ in first },
    ]
}

/// What the photo model is told, and the JSON it must reply with: a list of items, each the
/// shape of a typed line's reply plus whether it came from the food or from a label.
enum FoodPhotoPrompt {

    static let system = """
    You read a photo of food someone ate, or of a nutrition label, for a food log.

    For a photo of a meal or snack: list each separate food you can see as its own item (the chicken, the rice, the broccoli), with source "photo". Estimate each portion from what is visible (plate size, pieces, depth) and give macros for the whole visible portion. Include sauces, dressings and cooking fat you can see in the food they are on.

    For a photo of a nutrition label: give one item with source "label", read exactly from the label. name: the product, if the packaging shows it, else what the label is for ("Basmati rice"). quantity 1 and unit: the label's serving, with its size ("serving (100 g)", "bar (60 g)"). grams: the serving's weight if printed. calories, protein, fat and carbs: per serving, as printed (convert kJ only if no kcal is given).

    Rules for every item:
    - name: short and capitalised, without the amount ("Roast chicken", "Steamed broccoli").
    - quantity and unit: the portion as a person would count it; the unit is singular ("piece", "cup", "g", "slice").
    - grams: the whole portion's weight in grams if you can reasonably tell, else null.
    - calories in kcal; protein, fat and carbs in grams; for the whole portion.
    - assumption: one short sentence on what you assumed about the portion or preparation, or "".
    - match: null, unless a list of the person's saved foods follows.
    For a label item, read fiber, sodium, caffeine and alcohol exactly from the label when it prints them, and use null for any it doesn't.
    \(FoodExtrasPrompt.rules)
    The person may send a short note with the photo. Trust it over what you see: it can say how much they ate ("I ate half", "only the chicken"), what a food is ("it's turkey, not chicken"), or what was added that you can't see ("cooked in butter"). Apply it to the items and say so in their assumption.
    If there is no food or label in the photo, return no items.
    """

    /// The catalogue section, added after the rules when the user has saved foods.
    static func library(_ listing: String) -> String {
        """

        The person's saved foods and meals, by handle. If an item clearly is one of them, set its match: food is the handle, serving is the handle of the serving that fits (null for a meal, or when unsure), and quantity is how many of that serving (or of the meal). Otherwise match is null. Fill in the item's own fields either way.
        \(listing)
        """
    }

    static let schema: [String: Any] = {
        var item = FoodEstimatePrompt.schema
        var properties = item["properties"] as? [String: Any] ?? [:]
        properties["is_food"] = nil
        properties["needs_lookup"] = nil
        properties["parts"] = nil
        properties["source"] = ["type": "string", "enum": ["photo", "label"]]
        item["properties"] = properties
        item["required"] = ["source", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "assumption", "match"] + FoodExtrasPrompt.required
        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["items"],
            "properties": ["items": ["type": "array", "items": item]],
        ]
    }()
}

/// What the lookup model is told, and the JSON it must reply with. `found` is how the model
/// says it found nothing, or only a similar product, instead of sending numbers anyway; any
/// number it didn't find published is null. Tested as written (`lookup-test.md`).
enum FoodLookupPrompt {

    static let system = """
    You look up the published nutrition of one restaurant or packaged food that someone ate, described in a single line of a food log. Search the web for the brand's official nutrition information (the brand's or restaurant's own site first) and give the numbers for the whole portion described.

    - found: true only if you found published nutrition for this exact product (same brand, same product, same flavor or variety). If you only found a similar product, or nothing, found is false and the numbers are null.
    - product: the exact name of the product your numbers are for, as the source names it, or "" if not found.
    - source_url: the page the numbers come from, or "".
    - name: what the food is, short, with the brand.
    - quantity and unit: the portion as the person counts it; the unit is singular ("bowl", "bar", "g").
    - grams: the whole portion's weight if published, else null.
    - calories in kcal; protein, fat and carbs in grams; null for any you did not find published.
    - fiber_g (grams), sodium_mg (milligrams), caffeine_mg (milligrams) and alcohol_drinks (US standard drinks of 14 g pure alcohol, from the published strength and size): from the same published source, null for any it doesn't give. Never estimate these. A brand that doesn't publish caffeine gets null.
    - assumption: one short sentence naming where the numbers come from and anything assumed.
    - is_food is false only if the line cannot be something eaten or drunk. This is a food log: when a name could be a food or something else, it's the food.
    - Only when the line says they shared it or had part of it ("shared a large fries with my sister", "most of a burrito"): after finding the published numbers, scale them and the extras to their share (shared with one other person: half; with two others: a third; "most of": three quarters), set quantity to their share, and say so in the assumption. Otherwise give the published numbers as they are.
    """

    static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["is_food", "found", "product", "source_url", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "assumption"] + FoodExtrasPrompt.required,
        "properties": ([
            "is_food": ["type": "boolean"],
            "found": ["type": "boolean"],
            "product": ["type": "string"],
            "source_url": ["type": "string"],
            "name": ["type": "string"],
            "quantity": ["type": "number"],
            "unit": ["type": "string"],
            "grams": ["type": ["number", "null"]],
            "calories": ["type": ["number", "null"]],
            "protein": ["type": ["number", "null"]],
            "fat": ["type": ["number", "null"]],
            "carbs": ["type": ["number", "null"]],
            "assumption": ["type": "string"],
        ] as [String: Any]).merging(FoodExtrasPrompt.properties) { first, _ in first },
    ]

    /// The published label in a lookup's reply, or nil when the model found no label for this
    /// exact product or left any of the four numbers out. Throws `unreadable` for anything
    /// that isn't the schema's JSON.
    static func estimate(reply: Data) throws -> Estimate? {
        struct Reply: Decodable {
            let is_food: Bool
            let found: Bool
            let name: String
            let quantity: Double
            let unit: String
            let grams: Double?
            let calories: Double?
            let protein: Double?
            let fat: Double?
            let carbs: Double?
            let assumption: String
            let fiber_g: Double?
            let sodium_mg: Double?
            let caffeine_mg: Double?
            let alcohol_drinks: Double?
        }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: reply) else { throw Estimate.ReplyError.unreadable }
        guard reply.is_food, reply.found,
              let calories = reply.calories, let protein = reply.protein, let fat = reply.fat, let carbs = reply.carbs else { return nil }
        let unit = reply.unit.trimmingCharacters(in: .whitespaces)
        return Estimate(
            name: reply.name.trimmingCharacters(in: .whitespaces),
            quantity: reply.quantity,
            unit: unit.isEmpty ? "serving" : unit,
            grams: reply.grams.flatMap { $0 > 0 ? $0 : nil },
            macros: Macros(calories: calories, protein: protein, fat: fat, carbs: carbs),
            source: .lookedUp,
            assumption: plainText(reply.assumption).trimmingCharacters(in: .whitespaces),
            extras: Extras(fiber: reply.fiber_g, sodium: reply.sodium_mg, caffeine: reply.caffeine_mg, alcohol: reply.alcohol_drinks).normalised()
        )
    }

    /// The model writes its sources as Markdown links, "[questnutrition.com](https://…)"; the
    /// line's note shows text, so a link keeps only its words.
    static func plainText(_ text: String) -> String {
        text.replacing(/\[([^\]]*)\]\([^)]*\)/) { String($0.output.1) }
    }
}

/// The estimator the app uses: the text model through OpenRouter, then, for a restaurant or
/// brand food, the lookup model reading a web search (spec "Estimating" step 4). A lookup
/// that fails, can't be read, finds no label for this exact product, comes back impossible,
/// or comes back empty or partial leaves the text model's estimate standing.
final class OpenRouterFoodEstimator: FoodEstimator {

    private let client: OpenRouterClient

    init(client: OpenRouterClient) {
        self.client = client
    }

    func estimate(_ line: String, library: FoodLibrary) async throws -> Estimate {
        let reply = try await client.complete(
            model: FoodModels.text,
            system: FoodEstimatePrompt.system + (library.promptListing.map(FoodEstimatePrompt.library) ?? ""),
            user: [.text(line)],
            schema: (name: "estimate", json: FoodEstimatePrompt.schema),
            timeout: 20
        )
        let (estimate, match) = try Estimate.parse(reply: Data(reply.utf8), source: .estimated)
        if let resolved = match.flatMap({ library.resolve(food: $0.food, serving: $0.serving, quantity: $0.quantity) }) {
            return resolved
        }
        guard estimate.needsLookup else { return estimate }
        if let found = await lookUp(line, replacing: estimate) { return found }
        // No label for this brand or restaurant food: its fiber and sodium would be guesses
        // (tested: a guessed 150 mg for a drink with 5), so they are left blank. Caffeine and
        // alcohol stay: they are estimates that say what they assumed, and tested close.
        var kept = estimate
        kept.extras.fiber = nil
        kept.extras.sodium = nil
        return kept
    }

    func estimate(photo jpeg: Data, note: String?, library: FoodLibrary) async throws -> [Estimate] {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reply = try await client.complete(
            model: FoodModels.photo,
            system: FoodPhotoPrompt.system + (library.promptListing.map(FoodPhotoPrompt.library) ?? ""),
            user: [.jpeg(jpeg)] + (trimmed.isEmpty ? [] : [.text("Note from the person: \(trimmed)")]),
            schema: (name: "photo", json: FoodPhotoPrompt.schema),
            timeout: 40
        )
        return try Estimate.photoItems(reply: Data(reply.utf8)).map { estimate, match in
            match.flatMap { library.resolve(food: $0.food, serving: $0.serving, quantity: $0.quantity) } ?? estimate
        }
    }

    private func lookUp(_ line: String, replacing estimate: Estimate) async -> Estimate? {
        do {
            let reply = try await client.complete(
                model: FoodModels.lookup,
                system: FoodLookupPrompt.system,
                // The web search is made from this message: the line alone ("shin ramen") found
                // brand pages with calories but no sodium or fiber; asking for the label finds
                // the full panel (`.scratch/extras/accuracy-test/report.md`, run 3).
                user: [.text("\(line) nutrition facts")],
                schema: (name: "lookup", json: FoodLookupPrompt.schema),
                webSearch: FoodModels.lookupSearch,
                timeout: 25
            )
            guard let found = try FoodLookupPrompt.estimate(reply: Data(reply.utf8)) else {
                Self.logger.info("Lookup found no label for this exact product, keeping the estimate")
                return nil
            }
            guard found.impossibility == nil else {
                Self.logger.error("Lookup came back impossible")
                return nil
            }
            // A label read as 0s for a food the estimate gave calories to (a diet drink the
            // estimate also puts at 0 is real), or calories with no macros to make them up, is a
            // misread, not a label: the old lookup model sent its template's 0s back this way.
            let noMacros = [found.macros.protein, found.macros.fat, found.macros.carbs].allSatisfy { $0 == 0 }
            let isEmpty = noMacros && found.macros.calories == 0
            guard !isEmpty || estimate.macros.calories < 10, !noMacros || found.macros.calories < 10 else {
                Self.logger.error("Lookup came back empty or partial: \(found.assumption, privacy: .public)")
                return nil
            }
            return found
        } catch {
            Self.logger.error("Lookup failed, keeping the estimate: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static let logger = Logger(category: "Food")
}

#if DEBUG
/// Canned estimates for looking at the Describe tab in the simulator without a key: launch a
/// debug build with `-FakeFoodEstimates`. A line containing "offline" fails as no connection,
/// "fail" as a failed request, "asdf" as not a food, and "huge" with impossible numbers;
/// anything else is 100 kcal per word after a second. Never used by tests.
final class DebugFoodEstimator: FoodEstimator {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-FakeFoodEstimates")
    }

    /// A pretend key, held in memory, so the Describe tab doesn't ask for one.
    final class KeyStore: APIKeyStore {
        private var key: String? = "sk-or-debug"
        func read() -> String? { key }
        func save(_ key: String) throws { self.key = key }
        func delete() throws { key = nil }
    }

    /// Two plate items after two seconds; a third photo in a row fails, to see the retry.
    func estimate(photo jpeg: Data, note: String?, library: FoodLibrary) async throws -> [Estimate] {
        try await Task.sleep(for: .seconds(2))
        photos += 1
        if photos % 3 == 0 { throw OpenRouterError.failed("OpenRouter took too long to reply") }
        return [
            Estimate(name: "Roast chicken", quantity: 1, unit: "piece", grams: 180, macros: Macros(calories: 360, protein: 42, fat: 19, carbs: 0), source: .photo, assumption: "A made-up estimate for the simulator."),
            Estimate(name: "Steamed broccoli", quantity: 1, unit: "cup", grams: 90, macros: Macros(calories: 30, protein: 2.5, fat: 0.3, carbs: 6), source: .photo, assumption: ""),
        ]
    }

    private var photos = 0

    func estimate(_ line: String, library: FoodLibrary) async throws -> Estimate {
        try await Task.sleep(for: .seconds(1))
        let text = line.lowercased()
        if text.contains("offline") { throw OpenRouterError.offline }
        if text.contains("fail") { throw OpenRouterError.failed("OpenRouter: Upstream error") }
        if text.contains("asdf") { throw Estimate.ReplyError.notFood }
        let words = Double(max(1, line.split(separator: " ").count))
        let calories = text.contains("huge") ? 9_000 : 100 * words
        return Estimate(
            name: line.prefix(1).uppercased() + line.dropFirst(),
            quantity: 1,
            unit: "serving",
            grams: nil,
            macros: Macros(calories: calories, protein: calories / 20, fat: calories / 45, carbs: calories / 10),
            source: .estimated,
            assumption: "A made-up estimate for the simulator.",
            extras: Extras(
                fiber: words * 1.5,
                sodium: words * 120,
                caffeine: text.contains("coffee") ? 95 * words : nil,
                alcohol: text.contains("beer") || text.contains("wine") ? 1 : nil
            )
        )
    }
}
#endif
