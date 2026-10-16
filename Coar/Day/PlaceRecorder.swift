import CoreLocation
import MapKit
import os

/// Records where the user is, once a Day (`.scratch/day-page/issues/05`): when Coar becomes
/// active with location allowed and today has no place from the device yet, one rough fix
/// (about a kilometre), rounded to two decimals, and its city's name. Asks for location only
/// when the user taps to turn weather on.
@MainActor
final class PlaceRecorder: NSObject, CLLocationManagerDelegate {

    private static let logger = Logger(category: "Place")

    private let store: Store
    private let manager = CLLocationManager()
    private var fix: CheckedContinuation<CLLocation?, Never>?
    private var permission: CheckedContinuation<Void, Never>?
    private var recording = false

    init(store: Store) {
        self.store = store
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isAllowed: Bool {
        manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
    }

    /// Whether the system prompt has never been shown.
    var canAsk: Bool { manager.authorizationStatus == .notDetermined }

    /// Shows the prompt, then records today if allowed.
    func requestAccess() async {
        if canAsk {
            await withCheckedContinuation { continuation in
                permission = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        await recordToday()
    }

    /// Records today's place if allowed and not yet recorded by this or another device.
    func recordToday() async {
        let today = Day.today()
        guard isAllowed, !recording, (try? store.place(on: today))??.fromJournal != false else { return }
        recording = true
        defer { recording = false }
        guard let location = await withCheckedContinuation({ (continuation: CheckedContinuation<CLLocation?, Never>) in
            fix = continuation
            manager.requestLocation()
        }) else { return }
        let latitude = (location.coordinate.latitude * 100).rounded() / 100
        let longitude = (location.coordinate.longitude * 100).rounded() / 100
        var name = ""
        if let request = MKReverseGeocodingRequest(location: CLLocation(latitude: latitude, longitude: longitude)),
           let item = try? await request.mapItems.first {
            name = item.addressRepresentations?.cityWithContext ?? item.addressRepresentations?.cityName ?? item.name ?? ""
        }
        do {
            try store.setPlace(on: today, latitude: latitude, longitude: longitude, name: name, fromJournal: false)
        } catch {
            Self.logger.error("Failed to save today's place: \(error, privacy: .public)")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard manager.authorizationStatus != .notDetermined else { return }
            permission?.resume()
            permission = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            fix?.resume(returning: locations.last)
            fix = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            Self.logger.error("Location failed: \(error, privacy: .public)")
            fix?.resume(returning: nil)
            fix = nil
        }
    }
}
