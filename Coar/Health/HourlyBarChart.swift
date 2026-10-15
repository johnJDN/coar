import Charts
import SwiftUI

/// Steps by hour for one Day (DESIGN.md §8, the daily bars' vocabulary at hour scale): one
/// muted amber bar per hour with steps, the busiest saturated with bloom; hours without
/// steps are gaps; labels at 12 AM, 6 AM, 12 PM, 6 PM in `textTertiary`; `No steps` alone
/// when the Day has none. A SwiftUI leaf: values in, nothing out (ADR 0001).
struct HourlyBarChart: View {

    struct Model: Equatable {
        /// Steps per hour (0 is midnight), for the hours that have any.
        var hours: [Int: Int]
    }

    let model: Model

    @Environment(\.colorScheme) private var colorScheme

    private var busiest: Int? {
        model.hours.max { $0.value < $1.value }?.key
    }

    var body: some View {
        Chart {
            ForEach(model.hours.keys.sorted(), id: \.self) { hour in
                BarMark(x: .value("Hour", hour), y: .value("Steps", model.hours[hour] ?? 0), width: .fixed(8))
                    .foregroundStyle(Color.accentAmber.opacity(hour == busiest ? 1 : 0.6))
                    .cornerRadius(2)
                    .bloom(hour == busiest ? Color.accentAmber : .clear, in: colorScheme)
            }
        }
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis(model.hours.isEmpty ? .hidden : .automatic)
        .chartYAxis(model.hours.isEmpty ? .hidden : .automatic)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                if let hour = value.as(Int.self) {
                    AxisValueLabel(Self.hourText(hour))
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                if let number = value.as(Double.self) {
                    AxisValueLabel {
                        Text(HealthMetric.steps.axisText(number)).foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .overlay {
            if model.hours.isEmpty {
                Text("No steps").font(Font.bodyText).foregroundStyle(Color.textTertiary)
            }
        }
        .frame(height: 120)
        .accessibilityLabel(accessibilityText)
    }

    static func hourText(_ hour: Int) -> String {
        switch hour {
        case 0: return "12 AM"
        case 12: return "12 PM"
        default: return hour < 12 ? "\(hour) AM" : "\(hour - 12) PM"
        }
    }

    private var accessibilityText: String {
        guard let busiest else { return "No steps" }
        return "Steps by hour. Busiest \(Self.hourText(busiest)), \(HealthText.steps(model.hours[busiest] ?? 0)) steps"
    }
}

#Preview {
    HourlyBarChart(model: .init(hours: [7: 400, 8: 1_800, 9: 300, 12: 1_400, 13: 500, 17: 600, 18: 2_100, 19: 300]))
        .padding()
        .background(Color.surface)
}
