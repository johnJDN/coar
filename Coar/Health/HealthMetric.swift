import SwiftUI
import UIKit

/// The two things Coar reads from Apple Health and shows the same way: a hero value for
/// the current Day (last night's sleep, today's steps) and one bar per Day for 30 Days.
/// Sleep values are seconds; steps are a count.
enum HealthMetric: CaseIterable {
    case sleep
    case steps

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .steps: return "Steps"
        }
    }

    var systemImage: String {
        switch self {
        case .sleep: return "bed.double.fill"
        case .steps: return "figure.walk"
        }
    }

    /// One accent per metric (DESIGN.md §3): teal for Sleep, amber for Steps.
    var uiAccent: UIColor {
        switch self {
        case .sleep: return UIColor.accentTeal
        case .steps: return UIColor.accentAmber
        }
    }

    var accent: Color { Color(uiColor: uiAccent) }

    /// What the hero value is about: "Last night" or "Today".
    var periodCaption: String {
        switch self {
        case .sleep: return "Last night"
        case .steps: return "Today"
        }
    }

    /// The value as the hero shows it.
    func text(_ value: Double) -> String {
        switch self {
        case .sleep: return HealthText.duration(value)
        case .steps: return HealthText.steps(Int(value.rounded()))
        }
    }

    /// The value as the chart plots it: sleep in hours, steps as they are.
    func chartValue(_ value: Double) -> Double {
        switch self {
        case .sleep: return value / 3_600
        case .steps: return value
        }
    }

    /// A chart axis value: "6h", "5K".
    func axisText(_ chartValue: Double) -> String {
        switch self {
        case .sleep: return chartValue.formatted(.number.precision(.fractionLength(0...1))) + "h"
        case .steps: return chartValue.formatted(.number.notation(.compactName))
        }
    }

    /// The value per Day for `days`, for the Days that have one. Both come back as a
    /// `Double` (seconds, or a count) so one card and one chart serve both metrics.
    func read(_ days: [Day], from reader: HealthReader) async throws -> [Day: Double] {
        switch self {
        case .sleep: return try await reader.timeAsleep(wakingOn: days)
        case .steps: return try await reader.steps(on: days).mapValues(Double.init)
        }
    }
}
