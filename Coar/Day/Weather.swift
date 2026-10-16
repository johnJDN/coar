import CoreLocation
import Foundation
import WeatherKit
import os

/// A Day's weather where the user was (`.scratch/day-page/issues/05`): read live from Apple's
/// WeatherKit for the Day's place, never stored.
struct DayWeatherSummary: Equatable {
    /// "Light rain", "Mostly sunny".
    let condition: String
    let symbolName: String
    /// In °C.
    let high: Double
    let low: Double
    /// 0 to 1.
    let precipitationChance: Double

    /// "58° · light rain, high 61°" in the locale's unit.
    var text: String {
        "\(condition), high \(Self.degrees(high)), low \(Self.degrees(low))"
    }

    static func degrees(_ celsius: Double) -> String {
        let value = Vital.usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }
}

/// Where weather comes from. Faked in a simulator and in tests.
protocol WeatherProviding: AnyObject {
    func weather(on day: Day, latitude: Double, longitude: Double) async throws -> DayWeatherSummary?
    /// Apple's required attribution: the Apple Weather mark (light and dark) and the legal
    /// page. Nil when there's no weather to attribute.
    func attribution() async -> WeatherAttribution?
}

struct WeatherAttribution: Equatable {
    let markLight: URL
    let markDark: URL
    let legalPage: URL
}

/// Apple's WeatherKit: the Day's daily forecast, which also covers past Days.
final class WeatherKitProvider: WeatherProviding {

    private static let logger = Logger(category: "Weather")

    func weather(on day: Day, latitude: Double, longitude: Double) async throws -> DayWeatherSummary? {
        let start = day.start()
        let end = day.advanced(by: 1).start()
        let forecast = try await WeatherService.shared.weather(for: CLLocation(latitude: latitude, longitude: longitude), including: .daily(startDate: start, endDate: end))
        guard let today = forecast.forecast.first else { return nil }
        return DayWeatherSummary(
            condition: today.condition.description,
            symbolName: today.symbolName,
            high: today.highTemperature.converted(to: .celsius).value,
            low: today.lowTemperature.converted(to: .celsius).value,
            precipitationChance: today.precipitationChance
        )
    }

    func attribution() async -> WeatherAttribution? {
        do {
            let attribution = try await WeatherService.shared.attribution
            return WeatherAttribution(markLight: attribution.combinedMarkLightURL, markDark: attribution.combinedMarkDarkURL, legalPage: attribution.legalPageURL)
        } catch {
            Self.logger.error("Failed to read weather attribution: \(error, privacy: .public)")
            return nil
        }
    }
}

/// No weather: tests, and anywhere WeatherKit isn't wanted.
final class NoWeather: WeatherProviding {
    func weather(on day: Day, latitude: Double, longitude: Double) async throws -> DayWeatherSummary? { nil }
    func attribution() async -> WeatherAttribution? { nil }
}

#if DEBUG
/// Canned weather for a simulator (`-FakeHealthData`), the same for a Day on every launch.
final class DebugWeather: WeatherProviding {
    func weather(on day: Day, latitude: Double, longitude: Double) async throws -> DayWeatherSummary? {
        let options = [("Light rain", "cloud.drizzle"), ("Mostly cloudy", "cloud"), ("Partly sunny", "cloud.sun"), ("Sunny", "sun.max")]
        let pick = options[abs(day.rawValue.hashValue) % options.count]
        return DayWeatherSummary(condition: pick.0, symbolName: pick.1, high: 16, low: 9, precipitationChance: 0.4)
    }
    func attribution() async -> WeatherAttribution? { nil }
}
#endif
