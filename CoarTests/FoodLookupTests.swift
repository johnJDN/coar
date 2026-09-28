import XCTest
@testable import Coar

/// Restaurant and brand lookups (`.scratch/ai-food-logging/issues/06`). The text model marks
/// a line `needs_lookup`, the lookup model searches for the published numbers, and anything
/// short of a good answer keeps the text model's estimate. OpenRouter is a stubbed transport
/// answering per model; no test touches the network.
@MainActor
final class FoodLookupTests: XCTestCase {

    private func textReply(needsLookup: Bool, match: String = "null") -> String {
        #"{"is_food":true,"name":"Chipotle chicken bowl","quantity":1,"unit":"bowl","grams":null,"calories":650,"protein":35,"fat":25,"carbs":70,"needs_lookup":\#(needsLookup),"assumption":"Assumed a standard bowl.","match":\#(match)}"#
    }

    private let sonarReply = #"Here you go: ```json\n{"is_food": true, "name": "Chipotle chicken burrito bowl", "quantity": 1, "unit": "bowl", "grams": null, "calories": 635, "protein": 43, "fat": 20, "carbs": 69, "needs_lookup": false, "assumption": "Chipotle's nutrition calculator {chicken, rice}.", "match": "Chipotle bowl"}\n``` Enjoy!"#

    /// What the stubbed lookup model sends back.
    private enum Lookup {
        case reply(String)
        case status(Int)
    }

    /// A client whose replies depend on the model asked; records the models asked, in order.
    private func estimator(text: String, lookup: Lookup) -> (OpenRouterFoodEstimator, () -> [String]) {
        var asked: [String] = []
        let client = OpenRouterClient(keys: FakeAPIKeyStore(key: "sk-or-test")) { request in
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
            let model = body?["model"] as? String ?? ""
            asked.append(model)
            let (status, content): (Int, String)
            if model == FoodModels.lookup {
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
        return (OpenRouterFoodEstimator(client: client), { asked })
    }

    // MARK: Reading a lookup's reply

    func test_theJSON_isFoundInsideProseAndFences_withBracesInStrings() throws {
        let data = try XCTUnwrap(FoodLookupPrompt.object(in: sonarReply))
        let estimate = try Estimate(reply: data, source: .lookedUp)
        XCTAssertEqual(estimate.macros, Macros(calories: 635, protein: 43, fat: 20, carbs: 69))
        XCTAssertEqual(estimate.assumption, "Chipotle's nutrition calculator {chicken, rice}.")
        XCTAssertNil(try Estimate.parse(reply: data, source: .lookedUp).match, "a lookup's match, whatever it says, is dropped")
    }

    func test_aReplyWithNoObject_givesNothing() {
        XCTAssertNil(FoodLookupPrompt.object(in: "I couldn't find that."))
        XCTAssertNil(FoodLookupPrompt.object(in: "{ unfinished"))
    }

    // MARK: Routing

    func test_anEverydayFood_isNeverLookedUp() async throws {
        let (estimator, asked) = estimator(text: textReply(needsLookup: false), lookup: .reply(sonarReply))
        let estimate = try await estimator.estimate("chicken bowl", library: .empty)
        XCTAssertEqual(estimate.source, .estimated)
        XCTAssertEqual(asked(), [FoodModels.text])
    }

    func test_aChainFood_isLookedUp_andLabelledSo() async throws {
        let (estimator, asked) = estimator(text: textReply(needsLookup: true), lookup: .reply(sonarReply))
        let estimate = try await estimator.estimate("chipotle chicken bowl", library: .empty)
        XCTAssertEqual(asked(), [FoodModels.text, FoodModels.lookup])
        XCTAssertEqual(estimate.source, .lookedUp)
        XCTAssertEqual(estimate.macros.calories, 635)
        XCTAssertFalse(estimate.needsLookup)
    }

    func test_aFailedOrUnreadableOrImpossibleLookup_keepsTheEstimate() async throws {
        for lookup: Lookup in [.status(502), .reply("Sorry, no data."), .reply(sonarReply.replacingOccurrences(of: "\"calories\": 635", with: "\"calories\": 9000"))] {
            let (estimator, _) = estimator(text: textReply(needsLookup: true), lookup: lookup)
            let estimate = try await estimator.estimate("chipotle chicken bowl", library: .empty)
            XCTAssertEqual(estimate.source, .estimated)
            XCTAssertEqual(estimate.macros.calories, 650)
        }
    }

    func test_aSavedFood_isNotLookedUp() async throws {
        let store = Store.inMemory()
        let bowl = try store.createFoodItem(name: "Chipotle bowl", servings: [ServingDraft(name: "bowl", macros: Macros(calories: 700, protein: 45, fat: 22, carbs: 75), isDefault: true)])
        let library = FoodLibrary(foodItems: [bowl], meals: [])
        let (estimator, asked) = estimator(text: textReply(needsLookup: true, match: #"{"food":"f1","serving":null,"quantity":1}"#), lookup: .reply(sonarReply))
        let estimate = try await estimator.estimate("my chipotle", library: library)
        XCTAssertEqual(asked(), [FoodModels.text])
        XCTAssertEqual(estimate.source, .food)
        XCTAssertEqual(estimate.macros.calories, 700)
    }
}
