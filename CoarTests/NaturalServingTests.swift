import XCTest
@testable import Coar

/// A food's natural serving (`.scratch/food-logging/issues/02`): read from a reply, saved to
/// Foods with one piece beside it, used for a count, and several photos read together.
@MainActor
final class NaturalServingTests: XCTestCase {

    private let noon = Date(timeIntervalSince1970: 1_789_300_000)

    private func ritz(eaten quantity: Double, unit: String, grams: Double) -> Estimate {
        Estimate(name: "Ritz crackers", quantity: quantity, unit: unit, grams: grams,
                 macros: Macros(calories: 5 * grams, protein: 0.0625 * grams, fat: 0.25 * grams, carbs: 0.625 * grams),
                 source: .lookedUp, assumption: "", extras: Extras(sodium: 8.125 * grams),
                 servingSize: ServingSize(name: "5 crackers", grams: 16, piece: "cracker"))
    }

    func test_aReplysServing_isKeptOnlyWhenItsANamedServingWithAWeight() {
        XCTAssertEqual(ServingSize(reply: "5 crackers", grams: 16, piece: "cracker"), ServingSize(name: "5 crackers", grams: 16, piece: "cracker"))
        XCTAssertNil(ServingSize(reply: "None", grams: 42, piece: ""), "a model's 'None'")
        XCTAssertNil(ServingSize(reply: "100 g", grams: 100, piece: ""), "a weight isn't a serving")
        XCTAssertNil(ServingSize(reply: "1 breast", grams: nil, piece: ""))
        XCTAssertEqual(ServingSize(reply: "about 15 chips", grams: 28, piece: "chip")?.pieceCount, 15)
        XCTAssertNil(ServingSize(reply: "2/3 cup", grams: 55, piece: "")?.pieceCount)
    }

    func test_aLineInGrams_savesTheNaturalServingAndOnePiece() throws {
        let servings = try XCTUnwrap(ritz(eaten: 45, unit: "g", grams: 45).naturalServings)

        XCTAssertEqual(servings.map(\.name), ["5 crackers", "cracker"])
        XCTAssertEqual(servings[0].grams, 16)
        XCTAssertEqual(servings[0].macros.calories, 80, accuracy: 0.01)
        XCTAssertEqual(servings[0].extras.sodium ?? 0, 130, accuracy: 0.01)
        XCTAssertTrue(servings[0].isDefault)
        XCTAssertEqual(servings[1].grams ?? 0, 3.2, accuracy: 0.001)
        XCTAssertEqual(servings[1].macros.calories, 16, accuracy: 0.01)
    }

    func test_savingToFoods_keepsTheEntryAsTyped_andTheFoodsServings() throws {
        let store = Store.inMemory()

        try store.logDescribed(ritz(eaten: 45, unit: "g", grams: 45), typed: "45g ritz crackers", savingAsFood: true, at: noon)

        let entry = try XCTUnwrap(store.entries(on: Day(noon)).first)
        XCTAssertEqual(FoodText.portion(entry.quantity, of: entry.servingName), "45 g")
        XCTAssertEqual(entry.macros.calories, 225)
        let food = try XCTUnwrap(store.foodItem(named: "Ritz crackers"))
        XCTAssertEqual(food.servings.map(\.name), ["5 crackers", "cracker"])
        XCTAssertEqual(entry.foodItemID, food.id)
    }

    func test_aCountOfASavedFood_usesItsPiece_andGramsStillWork() throws {
        let store = Store.inMemory()
        try store.logDescribed(ritz(eaten: 45, unit: "g", grams: 45), typed: "45g ritz crackers", savingAsFood: true, at: noon)
        let library = FoodLibrary(foodItems: try store.foodItems(), meals: [])

        let eight = try XCTUnwrap(library.exactMatch("8 ritz crackers"))
        XCTAssertEqual(eight.unit, "cracker")
        XCTAssertEqual(eight.macros.calories, 128, accuracy: 0.01)
        XCTAssertEqual(library.exactMatch("ritz crackers")?.unit, "5 crackers", "no count: the usual serving")
        XCTAssertEqual(library.exactMatch("30g ritz crackers")?.macros.calories ?? 0, 150, accuracy: 0.01)
    }

    func test_withoutANaturalServing_savingIsAsBefore() {
        let plain = Estimate(name: "Rice", quantity: 150, unit: "g", grams: 150, macros: Macros(calories: 195, protein: 4, fat: 0, carbs: 43), source: .estimated, assumption: "")
        XCTAssertNil(plain.naturalServings)
        XCTAssertEqual(plain.servingToSave.serving.name, "100 g")
    }

    func test_theServing_survivesASavedDraft() throws {
        let estimate = ritz(eaten: 1, unit: "5 crackers (16 g)", grams: 16)
        let decoded = try JSONDecoder().decode(Estimate.self, from: JSONEncoder().encode(estimate))
        XCTAssertEqual(decoded.servingSize, estimate.servingSize)
    }

    func test_severalPhotos_areSentTogether() async throws {
        let estimator = FakeFoodEstimator()
        _ = try await estimator.estimate(photos: [Data([1]), Data([2])], note: nil, library: .empty)
        XCTAssertEqual(estimator.photosSent.count, 2)
    }

    func test_aPhotoReplysServing_isRead() throws {
        let reply = #"{"items":[{"source":"label","name":"Buttery crackers","quantity":1,"unit":"5 crackers (16 g)","grams":16,"calories":80,"protein":1,"fat":4,"carbs":10,"assumption":"","match":null,"fiber_g":0,"sodium_mg":130,"caffeine_mg":null,"alcohol_drinks":null,"serving_name":"5 crackers","serving_grams":16,"piece_name":"cracker"}]}"#
        let item = try XCTUnwrap(Estimate.photoItems(reply: Data(reply.utf8)).first)
        XCTAssertEqual(item.estimate.servingSize, ServingSize(name: "5 crackers", grams: 16, piece: "cracker"))
    }
}
