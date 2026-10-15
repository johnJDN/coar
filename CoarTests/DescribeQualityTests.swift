import XCTest
@testable import Coar

/// Describe quality of life (`.scratch/describe-qol/`): a line listing several foods splits into
/// one line each, your own foods are offered as you type, and a photo carries a note. Seam 2
/// (pure rules and parsing) and Seam 1 (the façade, in memory); the model is a fake.
@MainActor
final class DescribeQualityTests: XCTestCase {

    private let bowl = Macros(calories: 450, protein: 30, fat: 12, carbs: 55)

    // MARK: Several foods on one line

    func test_aReplyListingSeveralFoods_isReadAsSeveralFoods_andOneOrNoneIsNot() throws {
        let several = #"{"is_food":true,"name":"Breakfast","quantity":1,"unit":"plate","grams":null,"calories":450,"protein":20,"fat":20,"carbs":40,"needs_lookup":false,"assumption":"","match":null,"parts":["2 eggs"," toast ","coffee",""]}"#
        XCTAssertThrowsError(try Estimate.parse(reply: Data(several.utf8), source: .estimated)) {
            XCTAssertEqual($0 as? Estimate.ReplyError, .severalFoods(["2 eggs", "toast", "coffee"]))
        }
        let one = several.replacingOccurrences(of: #"["2 eggs"," toast ","coffee",""]"#, with: #"["toast with butter"]"#)
        XCTAssertNoThrow(try Estimate.parse(reply: Data(one.utf8), source: .estimated))
        let none = several.replacingOccurrences(of: #","parts":["2 eggs"," toast ","coffee",""]"#, with: "")
        XCTAssertNoThrow(try Estimate.parse(reply: Data(none.utf8), source: .estimated), "older replies without parts still read")
    }

    func test_aSplitLine_becomesOneLinePerFood_inItsPlace_keepingSaveToFoods() throws {
        var draft = DescribeDraft()
        let first = try XCTUnwrap(draft.lines.first?.id)
        draft.edit(first, text: "eggs, toast and coffee")
        draft.setSaveAsFood(first, false)
        let after = draft.insertLine(after: first)
        XCTAssertEqual(draft.begin(first), "eggs, toast and coffee")

        let ids = try XCTUnwrap(draft.split(first, sentText: "eggs, toast and coffee", into: ["2 eggs", "toast", "coffee"]))

        XCTAssertEqual(draft.lines.map(\.text), ["2 eggs", "toast", "coffee", ""])
        XCTAssertEqual(draft.lines.map(\.id).suffix(1), [after])
        XCTAssertEqual(ids.count, 3)
        XCTAssertTrue(draft.lines.prefix(3).allSatisfy { $0.state == .typing && !$0.saveAsFood })
    }

    func test_aSplit_forALineThatChangedSince_isDropped() throws {
        var draft = DescribeDraft()
        let line = try XCTUnwrap(draft.lines.first?.id)
        draft.edit(line, text: "burger and fries")
        _ = draft.begin(line)
        draft.edit(line, text: "burger")
        XCTAssertNil(draft.split(line, sentText: "burger and fries", into: ["burger", "fries"]))
        XCTAssertEqual(draft.lines.map(\.text), ["burger"])
    }

    func test_theTypedPrompt_asksForParts_andTheSizeRule() {
        let required = FoodEstimatePrompt.schema["required"] as? [String] ?? []
        XCTAssertTrue(required.contains("parts"))
        XCTAssertTrue(FoodEstimatePrompt.system.contains("parts:"))
        XCTAssertTrue(FoodEstimatePrompt.library("f1 Pho").contains("large about 1.5"))
        let photoItem = ((FoodPhotoPrompt.schema["properties"] as? [String: Any])?["items"] as? [String: Any])?["items"] as? [String: Any]
        XCTAssertNil((photoItem?["properties"] as? [String: Any])?["parts"], "a photo lists its own items")
    }

    // MARK: Your foods as you type

    private func library() throws -> FoodLibrary {
        let store = Store.inMemory()
        let pho = try store.createFoodItem(name: "Pho", servings: [ServingDraft(name: "bowl", macros: bowl, isDefault: true)])
        let shake = try store.createFoodItem(name: "Protein shake", servings: [ServingDraft(name: "bottle", macros: Macros(calories: 160, protein: 30, fat: 3, carbs: 4), isDefault: true)])
        let bun = try store.createFoodItem(name: "Bun cha", servings: [ServingDraft(name: "plate", macros: bowl, isDefault: true)])
        let meal = try store.createMeal(name: "Pho and spring rolls", components: [MealComponentDraft(foodItemID: pho.id, servingID: pho.servings[0].id, quantity: 1)])
        _ = meal
        return FoodLibrary(foodItems: [pho, shake, bun], meals: try store.meals())
    }

    func test_suggestions_offerNamesStartingWithWhatWasTyped_thenAWordOfThem() throws {
        let suggestions = try library().suggestions(for: "ph")
        XCTAssertEqual(suggestions.map(\.name), ["Pho", "Pho and spring rolls"])
        XCTAssertEqual(suggestions.first?.detail, "bowl · 450 cal")
        XCTAssertEqual(suggestions.last?.detail, "meal · 450 cal")
        XCTAssertEqual(try library().suggestions(for: "sha").map(\.name), ["Protein shake"], "a word of the name")
    }

    func test_aSuggestion_keepsTheAmountTyped_soItMatchesExactly() throws {
        let library = try library()
        let pick = try XCTUnwrap(library.suggestions(for: "2 ph").first)
        XCTAssertEqual(pick.text, "2 Pho")
        XCTAssertEqual(library.exactMatch(pick.text)?.quantity, 2)
        XCTAssertEqual(library.exactMatch(pick.text)?.source, .food)
    }

    func test_noSuggestions_forOneLetter_noMatch_orALineThatAlreadyIsAName() throws {
        let library = try library()
        XCTAssertEqual(library.suggestions(for: "p"), [])
        XCTAssertEqual(library.suggestions(for: "lasagna"), [])
        XCTAssertEqual(library.suggestions(for: "pho"), [])
    }

    // MARK: A note with a photo

    func test_aPhotosNote_isSentWithTheImage_andNoNoteSendsTheImageAlone() async throws {
        var bodies: [[String: Any]] = []
        let client = OpenRouterClient(keys: FakeAPIKeyStore(key: "sk-or-test")) { request in
            bodies.append(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any] ?? [:])
            let envelope = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": #"{"items":[]}"#]]]])
            return (envelope, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let estimator = OpenRouterFoodEstimator(client: client)
        _ = try await estimator.estimate(photo: Data([0xFF, 0xD8]), note: "  I ate half  ", library: .empty)
        _ = try await estimator.estimate(photo: Data([0xFF, 0xD8]), note: "   ", library: .empty)

        func userParts(_ body: [String: Any]) -> [[String: Any]] {
            let messages = body["messages"] as? [[String: Any]] ?? []
            return messages.last?["content"] as? [[String: Any]] ?? []
        }
        XCTAssertEqual(userParts(bodies[0]).compactMap { $0["text"] as? String }, ["Note from the person: I ate half"])
        XCTAssertEqual(userParts(bodies[0]).count, 2)
        XCTAssertEqual(userParts(bodies[1]).count, 1, "an empty note sends nothing")
        XCTAssertTrue(FoodPhotoPrompt.system.contains("note"))
    }
}
