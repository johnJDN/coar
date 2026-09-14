import XCTest
@testable import Coar

/// The unit setting is a device preference (ADR 0004: display-only, kilograms stored).
final class PreferencesTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_massUnit_defaultsToPounds() {
        XCTAssertEqual(Preferences(defaults: defaults).massUnit, .pounds)
    }

    func test_massUnit_onceChosen_isReadBackByAFreshInstance() {
        Preferences(defaults: defaults).massUnit = .kilograms

        XCTAssertEqual(Preferences(defaults: defaults).massUnit, .kilograms)
    }

    func test_changingMassUnit_notifiesObserversSoDisplayedWeightsUpdate() {
        let preferences = Preferences(defaults: defaults)
        let notified = expectation(forNotification: Preferences.massUnitDidChange, object: preferences)

        preferences.massUnit = .kilograms

        wait(for: [notified], timeout: 1)
    }
}
