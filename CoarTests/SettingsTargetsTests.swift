import SwiftUI
import UIKit
import XCTest
@testable import Coar

@MainActor
final class SettingsTargetsTests: XCTestCase {

    // MARK: Draft rule (pure)

    func test_draft_emptyFieldsAreZero_onceAnyFieldHasAValue() {
        let fields: [Macro: Double?] = [.calories: 2100, .protein: nil, .fat: nil, .carbs: nil]
        XCTAssertEqual(SettingsForm.draft(from: fields), Macros(calories: 2100, protein: 0, fat: 0, carbs: 0))
    }

    func test_draft_isNil_whenEveryFieldIsEmpty_orAnyIsNegative() {
        XCTAssertNil(SettingsForm.draft(from: [.calories: nil, .protein: nil, .fat: nil, .carbs: nil]))
        XCTAssertNil(SettingsForm.draft(from: [.calories: 2100, .protein: -1, .fat: 60, .carbs: 210]))
    }

    // MARK: The sheet, typed into

    private final class NoHealth: HealthAccess {
        func status() async -> HealthAccessStatus { .notRequested }
        func requestAccess() async throws {}
    }

    private func textFields(in view: UIView) -> [UITextField] {
        (view as? UITextField).map { [$0] } ?? view.subviews.flatMap(textFields(in:))
    }

    /// Types all four Targets and closes without any Save button: the Target is stored.
    func test_typedTargets_areSavedWhenTheSheetCloses() throws {
        let store = Store.inMemory()
        let dependencies = AppDependencies(
            store: store,
            preferences: Preferences(defaults: UserDefaults(suiteName: #function)!),
            health: NoHealth(),
            healthReader: FakeHealthReader(),
            bodyWeightWriter: FakeBodyWeightWriter(),
            restTimer: RestTimer()
        )
        let settings = SettingsViewController(dependencies: dependencies)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = settings
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))

        // A Form lays its rows out a pass after the window appears.
        settings.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let fields = textFields(in: window).filter { $0.keyboardType == .decimalPad }
        XCTAssertEqual(fields.count, 4)
        for (field, value) in zip(fields, ["2100", "180", "60", "210"]) {
            field.becomeFirstResponder()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            field.insertText(value)
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
        // Still editing the last field, as a user tapping Done at the top would be.
        settings.saveTargets()

        XCTAssertEqual(try store.target(inForceOn: .today())?.macros, Macros(calories: 2100, protein: 180, fat: 60, carbs: 210))
    }
}
