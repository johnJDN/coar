import Foundation

/// Turns one line the user typed into an Estimate (`.scratch/ai-food-logging/spec.md`,
/// "Estimating, cheapest first"), matching the user's catalogue when the line means one of
/// its foods. Throws an `OpenRouterError` when the request fails, or an
/// `Estimate.ReplyError` when the reply is not a food.
protocol FoodEstimator {
    func estimate(_ line: String, library: FoodLibrary) async throws -> Estimate
}

/// The models, one constant each, so swapping one is a one-line change (ADR 0007).
enum FoodModels {
    /// Everyday foods, typed: cheap and quick, with strict JSON.
    static let text = "google/gemini-3.1-flash-lite"
}

/// What the text model is told, and the JSON it must reply with. Every field is required
/// (strict schemas allow no optional ones); `grams` is null when unknown.
enum FoodEstimatePrompt {

    static let system = """
    You estimate the nutrition of one food someone ate, described in a single line of a food log.

    Rules:
    - One line is one food as eaten, even if it has parts ("toast with butter" is one food).
    - Give macros for the whole portion described. If no amount is given, assume one typical serving and say what you assumed.
    - name: what the food is, short and capitalised, without the amount ("Toast with butter", "Eggs").
    - quantity and unit: the portion as the person counts it. The unit is singular and describes one ("large egg", "slice", "cup", "g"). "2 eggs" is quantity 2, unit "large egg". "150g chicken" is quantity 150, unit "g".
    - grams: the whole portion's weight in grams if you can reasonably tell, else null.
    - calories in kcal; protein, fat and carbs in grams; all for the whole portion.
    - needs_lookup: true only when the line names a restaurant chain, a brand, or a packaged product whose published nutrition would be more accurate than an estimate. Otherwise false.
    - assumption: one short sentence on what you assumed, or "" if nothing.
    - is_food: false if the line is not something eaten or drunk; then the numbers are 0.
    - match: null, unless a list of the person's saved foods follows.
    """

    /// The catalogue section, added after the rules when the user has saved foods.
    static func library(_ listing: String) -> String {
        """

        The person's saved foods and meals, by handle. If the line clearly means one of them, set match: food is its handle, serving is the handle of the serving that fits what they said (null for a meal, or when they don't say), and quantity is how many of that serving (or of the meal). Match only when it is the same food as saved: not when the line adds something the saved food doesn't include ("with milk", "and fries"). Otherwise match is null. Fill in the estimate fields either way.
        \(listing)
        """
    }

    static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["is_food", "name", "quantity", "unit", "grams", "calories", "protein", "fat", "carbs", "needs_lookup", "assumption", "match"],
        "properties": [
            "is_food": ["type": "boolean"],
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
        ],
    ]
}

/// The estimator the app uses: the text model through OpenRouter.
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
        return match.flatMap { library.resolve(food: $0.food, serving: $0.serving, quantity: $0.quantity) } ?? estimate
    }
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
            assumption: "A made-up estimate for the simulator."
        )
    }
}
#endif
