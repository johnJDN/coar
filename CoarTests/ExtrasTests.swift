import XCTest
@testable import Coar

/// The four Extras an Entry may carry (`.scratch/extras/`): fiber, sodium, caffeine, alcohol.
/// Optional everywhere, nil meaning "not recorded", scaled with the portion, summed only over
/// what was recorded, and carried through the store, the models' replies, and the editors.
/// Seam 1 (the façade, in memory) and Seam 2 (pure rules and parsing).
@MainActor
final class ExtrasTests: XCTestCase {

    private let coffee = Extras(fiber: 0, sodium: 5, caffeine: 95, alcohol: nil)
    private let eggMacros = Macros(calories: 70, protein: 6, fat: 5, carbs: 0)

    // MARK: The value

    func test_scaling_multipliesWhatWasRecorded_andLeavesTheRestNil() {
        let scaled = Extras(fiber: 2, sodium: 100, caffeine: nil, alcohol: 0.5).scaled(by: 3)
        XCTAssertEqual(scaled, Extras(fiber: 6, sodium: 300, caffeine: nil, alcohol: 1.5))
    }

    func test_aSum_countsOnlyWhatWasRecorded_andAnExtraNobodyRecordedStaysNil() {
        let total = Extras.sum([Extras(fiber: 2, sodium: nil), Extras(fiber: 3, sodium: nil, caffeine: 80), Extras()])
        XCTAssertEqual(total, Extras(fiber: 5, sodium: nil, caffeine: 80, alcohol: nil))
        XCTAssertTrue(Extras.sum([]).isEmpty)
    }

    func test_normalising_takesZeroCaffeineAndAlcoholAsNone_butKeepsAZeroFiberOrSodium() {
        let value = Extras(fiber: 0, sodium: 0, caffeine: 0, alcohol: 0).normalised()
        XCTAssertEqual(value, Extras(fiber: 0, sodium: 0, caffeine: nil, alcohol: nil))
        XCTAssertEqual(Extras(fiber: -1, sodium: .nan, caffeine: .infinity, alcohol: 1).normalised(), Extras(fiber: nil, sodium: nil, caffeine: nil, alcohol: 1))
    }

    func test_typedFields_anEmptyOneIsNotRecorded_andANegativeOneIsInvalid() {
        XCTAssertEqual(Extras(typed: [.fiber: 4, .sodium: nil]), Extras(fiber: 4))
        XCTAssertNil(Extras(typed: [.caffeine: -5]))
    }

    func test_text_showsTheUnit_andOneDrinkInTheSingular() {
        XCTAssertEqual(Extra.fiber.text(3.4), "3 g")
        XCTAssertEqual(Extra.sodium.text(1_010), "1010 mg")
        XCTAssertEqual(Extra.caffeine.text(94.6), "95 mg")
        XCTAssertEqual(Extra.alcohol.text(1), "1 drink")
        XCTAssertEqual(Extra.alcohol.text(0.96), "1 drink")
        XCTAssertEqual(Extra.alcohol.text(1.5), "1.5 drinks")
    }

    // MARK: The store

    func test_loggingAFoodItem_copiesItsServingsExtras_scaledByTheQuantity() throws {
        let store = Store.inMemory()
        let food = try store.createFoodItem(name: "Latte", servings: [ServingDraft(name: "1 cup", macros: eggMacros, isDefault: true, extras: coffee)])

        let entry = try store.logEntry(foodItem: food.id, serving: food.servings[0].id, quantity: 2, at: Date())

        XCTAssertEqual(entry.extras, Extras(fiber: 0, sodium: 10, caffeine: 190, alcohol: nil))
        XCTAssertEqual(try store.entry(entry.id)?.extras, entry.extras)
    }

    func test_aFoodWithNoExtras_logsNone_notZeros() throws {
        let store = Store.inMemory()
        let food = try store.createFoodItem(name: "Eggs", servings: [ServingDraft(name: "1 egg", macros: eggMacros, isDefault: true)])
        let entry = try store.logEntry(foodItem: food.id, serving: food.servings[0].id, quantity: 3, at: Date())
        XCTAssertTrue(entry.extras.isEmpty)
    }

    func test_aMealEntry_sumsItsLinesExtras_andKeepsThemInItsBreakdown() throws {
        let store = Store.inMemory()
        let latte = try store.createFoodItem(name: "Latte", servings: [ServingDraft(name: "1 cup", macros: eggMacros, isDefault: true, extras: Extras(sodium: 100, caffeine: 150))])
        let bar = try store.createFoodItem(name: "Bar", servings: [ServingDraft(name: "1 bar", macros: eggMacros, isDefault: true, extras: Extras(fiber: 14, sodium: 230))])
        let meal = try store.createMeal(name: "Pre-gym", components: [
            MealComponentDraft(foodItemID: latte.id, servingID: latte.servings[0].id, quantity: 1),
            MealComponentDraft(foodItemID: bar.id, servingID: bar.servings[0].id, quantity: 2),
        ])
        XCTAssertEqual(meal.extras, Extras(fiber: 28, sodium: 560, caffeine: 150, alcohol: nil))

        let entry = try store.logEntry(meal: meal.id, quantity: 2, at: Date())

        XCTAssertEqual(entry.extras, Extras(fiber: 56, sodium: 1_120, caffeine: 300, alcohol: nil))
        XCTAssertEqual(entry.components.map(\.extras), [Extras(sodium: 100, caffeine: 150), Extras(fiber: 28, sodium: 460)])
    }

    func test_aStandAloneEntry_keepsTheExtrasItWasLoggedWith() throws {
        let store = Store.inMemory()
        let entry = try store.logEntry(name: "Beer", servingName: "can", quantity: 1, macros: eggMacros, extras: Extras(sodium: 14, alcohol: 1), at: Date())
        XCTAssertEqual(try store.entry(entry.id)?.extras, Extras(sodium: 14, alcohol: 1))
    }

    func test_correctingAnEntry_setsItsExtras_andLeavesThemWhenNoneAreGiven() throws {
        let store = Store.inMemory()
        let entry = try store.logEntry(name: "Coffee", servingName: "cup", quantity: 1, macros: eggMacros, extras: Extras(caffeine: 95), at: Date())

        try store.updateEntry(entry.id, loggedAt: entry.loggedAt, quantity: 1, macros: eggMacros)
        XCTAssertEqual(try store.entry(entry.id)?.extras, Extras(caffeine: 95), "no Extras given: left as they were")

        try store.updateEntry(entry.id, loggedAt: entry.loggedAt, quantity: 1, macros: eggMacros, extras: Extras(fiber: 1, caffeine: 120))
        XCTAssertEqual(try store.entry(entry.id)?.extras, Extras(fiber: 1, caffeine: 120))

        try store.updateEntry(entry.id, loggedAt: entry.loggedAt, quantity: 1, macros: eggMacros, extras: Extras())
        XCTAssertTrue(try XCTUnwrap(store.entry(entry.id)).extras.isEmpty, "cleared on purpose")
    }

    func test_anUndoneDelete_bringsTheExtrasBack_theEntrysAndItsBreakdowns() throws {
        let store = Store.inMemory()
        let latte = try store.createFoodItem(name: "Latte", servings: [ServingDraft(name: "1 cup", macros: eggMacros, isDefault: true, extras: Extras(caffeine: 150))])
        let meal = try store.createMeal(name: "Coffee run", components: [MealComponentDraft(foodItemID: latte.id, servingID: latte.servings[0].id, quantity: 1)])
        let entry = try store.logEntry(meal: meal.id, quantity: 1, at: Date())

        try store.deleteEntry(entry.id)
        try store.restoreEntry(entry)

        let back = try XCTUnwrap(store.entry(entry.id))
        XCTAssertEqual(back.extras, Extras(caffeine: 150))
        XCTAssertEqual(back.components.map(\.extras), [Extras(caffeine: 150)])
    }

    func test_saveAsFood_savesTheExtrasPerOne_andLogsThemBack() throws {
        let store = Store.inMemory()
        let entry = try store.logEntry(name: "Red Bull", servingName: "can", quantity: 2, macros: eggMacros, extras: Extras(sodium: 200, caffeine: 160), at: Date())

        let food = try XCTUnwrap(store.saveEntryAsFood(entry.id))

        XCTAssertEqual(food.defaultServing?.extras, Extras(sodium: 100, caffeine: 80))
        let again = try store.logEntry(foodItem: food.id, serving: food.servings[0].id, quantity: 1, at: Date())
        XCTAssertEqual(again.extras, Extras(sodium: 100, caffeine: 80))
    }

    func test_aServingsExtras_areEditedWithTheFoodItem() throws {
        let store = Store.inMemory()
        let food = try store.createFoodItem(name: "Bar", servings: [ServingDraft(name: "1 bar", macros: eggMacros, isDefault: true, extras: Extras(fiber: 14))])
        var draft = ServingDraft(food.servings[0])
        draft.extras = Extras(fiber: 12, sodium: 230)
        try store.updateFoodItem(food.id, name: "Bar", servings: [draft])
        XCTAssertEqual(try store.foodItem(food.id)?.servings[0].extras, Extras(fiber: 12, sodium: 230))
    }

    // MARK: Reading what a model says

    func test_aTextReply_givesItsExtras_withZeroCaffeineAndAlcoholTakenAsNone() throws {
        let reply = #"{"is_food":true,"name":"Banana","quantity":1,"unit":"medium banana","grams":118,"calories":105,"protein":1.3,"fat":0.4,"carbs":27,"needs_lookup":false,"assumption":"","match":null,"fiber_g":3.1,"sodium_mg":1,"caffeine_mg":0,"alcohol_drinks":null}"#
        let estimate = try Estimate.parse(reply: Data(reply.utf8), source: .estimated).estimate
        XCTAssertEqual(estimate.extras, Extras(fiber: 3.1, sodium: 1, caffeine: nil, alcohol: nil))
    }

    func test_aReplyWithoutTheExtraFields_stillReads_withNoneRecorded() throws {
        let reply = #"{"is_food":true,"name":"Toast","quantity":1,"unit":"slice","grams":null,"calories":80,"protein":3,"fat":1,"carbs":15,"needs_lookup":false,"assumption":"","match":null}"#
        XCTAssertTrue(try Estimate.parse(reply: Data(reply.utf8), source: .estimated).estimate.extras.isEmpty)
    }

    func test_aPhotoItem_givesItsExtras_aLabelsExactly() throws {
        let reply = #"{"items":[{"source":"label","name":"Red Bull","quantity":1,"unit":"can (250 ml)","grams":null,"calories":110,"protein":0,"fat":0,"carbs":27,"assumption":"","match":null,"fiber_g":0,"sodium_mg":105,"caffeine_mg":80,"alcohol_drinks":null}]}"#
        let item = try XCTUnwrap(Estimate.photoItems(reply: Data(reply.utf8)).first?.estimate)
        XCTAssertEqual(item.extras, Extras(fiber: 0, sodium: 105, caffeine: 80, alcohol: nil))
    }

    func test_aLookup_givesItsExtras_andNullsStayNil() throws {
        let reply = #"{"is_food":true,"found":true,"product":"Chicken Sandwich","source_url":"https://x","name":"Chick-fil-A Chicken Sandwich","quantity":1,"unit":"sandwich","grams":null,"calories":420,"protein":29,"fat":16,"carbs":41,"fiber_g":2,"sodium_mg":1350,"caffeine_mg":null,"alcohol_drinks":null,"assumption":"From chick-fil-a.com"}"#
        let estimate = try XCTUnwrap(FoodLookupPrompt.estimate(reply: Data(reply.utf8)))
        XCTAssertEqual(estimate.extras, Extras(fiber: 2, sodium: 1_350, caffeine: nil, alcohol: nil))
    }

    func test_aBrandFoodWithNoLabelFound_keepsItsCaffeineAndAlcohol_butNotGuessedFiberAndSodium() async throws {
        let guessed = #"{"is_food":true,"name":"Celsius","quantity":1,"unit":"can","grams":null,"calories":10,"protein":0,"fat":0,"carbs":2,"needs_lookup":true,"assumption":"Assumed a 12 oz can.","match":null,"fiber_g":0,"sodium_mg":150,"caffeine_mg":200,"alcohol_drinks":null}"#
        let client = OpenRouterClient(keys: FakeAPIKeyStore(key: "sk-or-test")) { request in
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
            let isLookup = body?["plugins"] != nil
            let content = isLookup ? #"{"is_food":true,"found":false,"product":"","source_url":"","name":"Celsius","quantity":1,"unit":"can","grams":null,"calories":null,"protein":null,"fat":null,"carbs":null,"assumption":"","fiber_g":null,"sodium_mg":null,"caffeine_mg":null,"alcohol_drinks":null}"# : guessed
            let envelope = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]], "usage": ["cost": 0.001]])
            return (envelope, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let estimate = try await OpenRouterFoodEstimator(client: client).estimate("celsius", library: .empty)
        XCTAssertEqual(estimate.source, .estimated)
        XCTAssertEqual(estimate.extras, Extras(fiber: nil, sodium: nil, caffeine: 200, alcohol: nil))
    }

    func test_everyPromptAndSchemaAsksForTheFourExtras() {
        for schema in [FoodEstimatePrompt.schema, FoodLookupPrompt.schema, FoodPhotoPrompt.schema] {
            let item = (schema["properties"] as? [String: Any])?["items"] as? [String: Any]
            let target = item?["items"] as? [String: Any] ?? schema
            let required = target["required"] as? [String] ?? []
            let properties = target["properties"] as? [String: Any] ?? [:]
            for key in FoodExtrasPrompt.required {
                XCTAssertTrue(required.contains(key), "\(key) is required")
                XCTAssertNotNil(properties[key], "\(key) is a property")
            }
        }
        for prompt in [FoodEstimatePrompt.system, FoodPhotoPrompt.system] {
            XCTAssertTrue(prompt.contains("alcohol_drinks"))
        }
        XCTAssertTrue(FoodLookupPrompt.system.contains("alcohol_drinks"))
    }

    // MARK: Saved drafts and the cache

    func test_anEstimateSavedByAnOlderBuild_stillLoads_withNoExtras() throws {
        let old = #"{"name":"Toast","quantity":1,"unit":"slice","macros":{"calories":80,"protein":3,"fat":1,"carbs":15},"source":"estimated","assumption":"","needsLookup":false}"#
        let estimate = try JSONDecoder().decode(Estimate.self, from: Data(old.utf8))
        XCTAssertEqual(estimate.name, "Toast")
        XCTAssertTrue(estimate.extras.isEmpty)
    }

    func test_anEstimateWithExtras_roundTrips_andOmitsThemWhenThereAreNone() throws {
        var estimate = Estimate(name: "Coffee", quantity: 1, unit: "cup", grams: nil, macros: eggMacros, source: .estimated, assumption: "")
        estimate.extras = Extras(sodium: 5, caffeine: 95)
        XCTAssertEqual(try JSONDecoder().decode(Estimate.self, from: JSONEncoder().encode(estimate)), estimate)

        estimate.extras = Extras()
        let plain = String(decoding: try JSONEncoder().encode(estimate), as: UTF8.self)
        XCTAssertFalse(plain.contains("extras"))
    }

    // MARK: The library

    func test_aSavedFoodAMatchResolvesTo_carriesItsExtras_scaled() throws {
        let store = Store.inMemory()
        let latte = try store.createFoodItem(name: "Latte", servings: [ServingDraft(name: "1 cup", macros: eggMacros, isDefault: true, extras: coffee)])
        let library = FoodLibrary(foodItems: [latte], meals: [])
        let estimate = try XCTUnwrap(library.resolve(food: "f1", serving: "s1", quantity: 2))
        XCTAssertEqual(estimate.extras, Extras(fiber: 0, sodium: 10, caffeine: 190, alcohol: nil))
    }

    // MARK: The editors

    func test_anEntryPage_showsTheExtrasItHolds_scalesThemWithTheQuantity_andKeepsAClearedRow() {
        let record = EntryRecord(
            id: UUID(), loggedAt: Date(), day: Day.today(), name: "Latte", servingName: "cup", quantity: 1, macros: eggMacros,
            foodItemID: nil, mealID: nil, components: [], modifiedAt: Date(), extras: Extras(sodium: 100, caffeine: 150)
        )
        var draft = EntryDraft(record)
        XCTAssertEqual(draft.shownExtras, [.sodium, .caffeine])

        draft.setQuantity(2)
        XCTAssertEqual(draft.extras, Extras(sodium: 200, caffeine: 300))

        draft.typedExtras[.caffeine] = .some(nil)
        XCTAssertEqual(draft.shownExtras, [.sodium, .caffeine], "a cleared row stays so it can be typed again")
        XCTAssertEqual(draft.extras, Extras(sodium: 200))

        draft.typedExtras[.sodium] = -1
        XCTAssertFalse(draft.isSaveable)
    }

    func test_anEntryWithoutExtras_showsNoRows() {
        let record = EntryRecord(id: UUID(), loggedAt: Date(), day: Day.today(), name: "Eggs", servingName: "egg", quantity: 1, macros: eggMacros, foodItemID: nil, mealID: nil, components: [], modifiedAt: Date())
        XCTAssertTrue(EntryDraft(record).shownExtras.isEmpty)
    }

    func test_aDescribeLinePage_scalesItsExtras_andTypingOneMakesTheLineYourOwn() {
        var estimate = Estimate(name: "Latte", quantity: 1, unit: "cup", grams: nil, macros: eggMacros, source: .food, assumption: "", match: .foodItem(UUID(), serving: UUID()))
        estimate.extras = Extras(caffeine: 150)
        var edit = DescribeLineEdit(DescribeLine(text: "latte", state: .filled(estimate)))
        XCTAssertEqual(edit.shownExtras, [.caffeine])

        edit.setQuantity(2)
        XCTAssertEqual(edit.estimate?.extras, Extras(caffeine: 300))
        XCTAssertNotNil(edit.estimate?.match, "a quantity alone keeps the match")

        edit.setExtra(.caffeine, 120)
        XCTAssertEqual(edit.estimate?.extras, Extras(caffeine: 120))
        XCTAssertNil(edit.estimate?.match, "typing an Extra makes it the user's own")
        XCTAssertEqual(edit.estimate?.source, .typed)
    }
}
