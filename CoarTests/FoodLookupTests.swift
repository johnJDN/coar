import XCTest
@testable import Coar

/// Restaurant and brand lookups (`.scratch/ai-food-logging/issues/06`). The text model marks
/// a line `needs_lookup`, the lookup model reads a web search for the published label, and
/// anything short of a label for this exact product keeps the text model's estimate. The
/// lookup replies are the real ones from `.scratch/ai-food-logging/lookup-test/` where there
/// is one. OpenRouter is a stubbed transport answering per model; no test touches the network.
@MainActor
final class FoodLookupTests: XCTestCase {

    private func textReply(needsLookup: Bool, calories: Int = 650, match: String = "null") -> String {
        #"{"is_food":true,"name":"Chipotle chicken bowl","quantity":1,"unit":"bowl","grams":null,"calories":\#(calories),"protein":35,"fat":25,"carbs":70,"needs_lookup":\#(needsLookup),"assumption":"Assumed a standard bowl.","match":\#(match)}"#
    }

    /// Gemini + Exa's reply for "quest cookie dough bar" (2026-10-03).
    private let questReply = #"{"is_food": true, "found": true, "product": "Chocolate Chip Cookie Dough Protein Bar", "source_url": "https://www.questnutrition.com/products/chocolate-chip-cookie-dough-protein-bar", "name": "Quest Nutrition Chocolate Chip Cookie Dough Protein Bar", "quantity": 1, "unit": "bar", "grams": 60, "calories": 190, "protein": 21, "fat": 9, "carbs": 22, "assumption": "Nutrition information is sourced from the official [questnutrition.com](https://www.questnutrition.com/products/chocolate-chip-cookie-dough-protein-bar) website for a single 60g bar."}"#

    /// What the stubbed lookup model sends back.
    private enum Lookup {
        case reply(String)
        case status(Int)
    }

    /// A client whose replies depend on the model asked; records each request's body, in order.
    private func estimator(text: String, lookup: Lookup) -> (OpenRouterFoodEstimator, () -> [[String: Any]]) {
        var bodies: [[String: Any]] = []
        let client = OpenRouterClient(keys: FakeAPIKeyStore(key: "sk-or-test")) { request in
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any] ?? [:]
            bodies.append(body)
            let (status, content): (Int, String)
            if body["plugins"] != nil {
                switch lookup {
                case .reply(let reply): (status, content) = (200, reply)
                case .status(let code): (status, content) = (code, "")
                }
            } else {
                (status, content) = (200, text)
            }
            let envelope = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]], "usage": ["cost": 0.001]])
            return (status == 200 ? envelope : Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        return (OpenRouterFoodEstimator(client: client), { bodies })
    }

    // MARK: Reading a lookup's reply

    func test_aLabelForThisExactProduct_isRead_withItsSourceAsPlainText() throws {
        let estimate = try XCTUnwrap(FoodLookupPrompt.estimate(reply: Data(questReply.utf8)))
        XCTAssertEqual(estimate.macros, Macros(calories: 190, protein: 21, fat: 9, carbs: 22))
        XCTAssertEqual(estimate.portion, FoodText.quantity(1, of: "bar"))
        XCTAssertEqual(estimate.grams, 60)
        XCTAssertEqual(estimate.source, .lookedUp)
        XCTAssertEqual(estimate.assumption, "Nutrition information is sourced from the official questnutrition.com website for a single 60g bar.")
    }

    func test_notFound_orAnyNumberLeftOut_givesNoLabel() throws {
        // Real replies: a flavour Quest doesn't make, and Panera's calories without the macros.
        let notFound = #"{"is_food": true, "found": false, "product": "", "source_url": "", "name": "Quest Dark Chocolate Raspberry Bar", "quantity": 1, "unit": "bar", "grams": null, "calories": null, "protein": null, "fat": null, "carbs": null, "assumption": "Only White Chocolate Raspberry was found."}"#
        let partial = #"{"is_food": true, "found": true, "product": "Bacon Turkey Bravo", "source_url": "https://postmates.com/", "name": "Panera Bread Bacon Turkey Bravo", "quantity": 1, "unit": "whole", "grams": null, "calories": 860, "protein": null, "fat": null, "carbs": null, "assumption": "Macronutrients were not listed on this source."}"#
        XCTAssertNil(try FoodLookupPrompt.estimate(reply: Data(notFound.utf8)))
        XCTAssertNil(try FoodLookupPrompt.estimate(reply: Data(partial.utf8)))
    }

    func test_aReplyThatIsNotTheSchema_isUnreadable() {
        XCTAssertThrowsError(try FoodLookupPrompt.estimate(reply: Data("I couldn't find that.".utf8))) {
            XCTAssertEqual($0 as? Estimate.ReplyError, .unreadable)
        }
    }

    // MARK: Routing

    func test_anEverydayFood_isNeverLookedUp() async throws {
        let (estimator, bodies) = estimator(text: textReply(needsLookup: false), lookup: .reply(questReply))
        let estimate = try await estimator.estimate("chicken bowl", library: .empty)
        XCTAssertEqual(estimate.source, .estimated)
        XCTAssertEqual(bodies().count, 1)
    }

    func test_aBrandFood_isLookedUpThroughExa_withTheStrictSchema_andLabelledSo() async throws {
        let (estimator, bodies) = estimator(text: textReply(needsLookup: true), lookup: .reply(questReply))
        let estimate = try await estimator.estimate("quest cookie dough bar", library: .empty)

        XCTAssertEqual(bodies().map { $0["model"] as? String }, [FoodModels.text, FoodModels.lookup])
        let lookup = bodies()[1]
        let plugin = try XCTUnwrap((lookup["plugins"] as? [[String: Any]])?.first)
        XCTAssertEqual(plugin["id"] as? String, "web")
        XCTAssertEqual(plugin["engine"] as? String, "exa")
        XCTAssertEqual(plugin["max_results"] as? Int, 5)
        XCTAssertEqual(((lookup["response_format"] as? [String: Any])?["json_schema"] as? [String: Any])?["name"] as? String, "lookup")
        XCTAssertNil(bodies()[0]["plugins"], "the first guess doesn't search")

        XCTAssertEqual(estimate.source, .lookedUp)
        XCTAssertEqual(estimate.macros.calories, 190)
        XCTAssertFalse(estimate.needsLookup)
    }

    func test_aFailedUnreadableNotFoundOrImpossibleLookup_keepsTheEstimate() async throws {
        let notFound = questReply.replacingOccurrences(of: #""found": true"#, with: #""found": false"#)
        let impossible = questReply.replacingOccurrences(of: #""calories": 190"#, with: #""calories": 9000"#)
        for lookup: Lookup in [.status(502), .reply("Sorry, no data."), .reply(notFound), .reply(impossible)] {
            let (estimator, _) = estimator(text: textReply(needsLookup: true), lookup: lookup)
            let estimate = try await estimator.estimate("quest cookie dough bar", library: .empty)
            XCTAssertEqual(estimate.source, .estimated)
            XCTAssertEqual(estimate.macros.calories, 650)
        }
    }

    func test_aLabelReadAsZeros_orCaloriesWithNoMacros_keepsTheEstimate() async throws {
        let zeros = questReply.replacingOccurrences(of: #""calories": 190, "protein": 21, "fat": 9, "carbs": 22"#, with: #""calories": 0, "protein": 0, "fat": 0, "carbs": 0"#)
        let caloriesOnly = questReply.replacingOccurrences(of: #""protein": 21, "fat": 9, "carbs": 22"#, with: #""protein": 0, "fat": 0, "carbs": 0"#)
        for reply in [zeros, caloriesOnly] {
            let (estimator, _) = estimator(text: textReply(needsLookup: true), lookup: .reply(reply))
            let estimate = try await estimator.estimate("quest cookie dough bar", library: .empty)
            XCTAssertEqual(estimate.source, .estimated)
            XCTAssertEqual(estimate.macros.calories, 650)
        }
    }

    func test_aZeroCalorieDrink_isStillLookedUp() async throws {
        // Gemini + Exa's real reply for "diet coke can".
        let dietCoke = #"{"is_food": true, "found": true, "product": "Diet Coke", "source_url": "https://www.coca-cola.com/us/en/brands/diet-coke/products", "name": "Diet Coke can", "quantity": 1, "unit": "can", "grams": null, "calories": 0, "protein": 0, "fat": 0, "carbs": 0, "assumption": "Nutrition facts are sourced from coca-cola.com for 1 standard 12 fl oz can of Diet Coke."}"#
        let (estimator, _) = estimator(text: textReply(needsLookup: true, calories: 0), lookup: .reply(dietCoke))
        let estimate = try await estimator.estimate("diet coke can", library: .empty)
        XCTAssertEqual(estimate.source, .lookedUp)
        XCTAssertEqual(estimate.macros.calories, 0)
    }

    func test_aSavedFood_isNotLookedUp() async throws {
        let store = Store.inMemory()
        let bowl = try store.createFoodItem(name: "Chipotle bowl", servings: [ServingDraft(name: "bowl", macros: Macros(calories: 700, protein: 45, fat: 22, carbs: 75), isDefault: true)])
        let library = FoodLibrary(foodItems: [bowl], meals: [])
        let (estimator, bodies) = estimator(text: textReply(needsLookup: true, match: #"{"food":"f1","serving":null,"quantity":1}"#), lookup: .reply(questReply))
        let estimate = try await estimator.estimate("my chipotle", library: library)
        XCTAssertEqual(bodies().count, 1)
        XCTAssertEqual(estimate.source, .food)
        XCTAssertEqual(estimate.macros.calories, 700)
    }
}
