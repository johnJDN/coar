import Charts
import SwiftUI

/// The Exercise detail page's Progression chart (DESIGN.md §8 "Trend over time"): one point
/// per Workout containing the Exercise, its Estimated 1RM in the display unit, joined by a
/// 2pt `accentLime` line with bloom on the last point; no gridlines, no legend, axis labels in
/// `textTertiary`. A single Workout is one bloomed point and no line; no Workouts is `No data`
/// in the slot. A SwiftUI leaf: values in, nothing out (ADR 0001).
struct ProgressionChart: View {

    struct Model: Equatable {
        var points: [TrendPoint]
        var unit: String
    }

    let model: Model

    @Environment(\.colorScheme) private var colorScheme

    private static let accent = Color.accentLime

    var body: some View {
        Chart {
            if model.points.count >= 2 {
                ForEach(model.points) { point in
                    LineMark(x: .value("Workout", point.date), y: .value("Estimated 1RM", point.value))
                        .foregroundStyle(Self.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
            }
            ForEach(model.points.dropLast()) { point in
                PointMark(x: .value("Workout", point.date), y: .value("Estimated 1RM", point.value))
                    .foregroundStyle(Self.accent)
                    .symbolSize(24)
            }
            if let last = model.points.last {
                PointMark(x: .value("Workout", last.date), y: .value("Estimated 1RM", last.value))
                    .foregroundStyle(Self.accent)
                    .symbolSize(56)
                    .bloom(Self.accent, in: colorScheme)
            }
        }
        .trendChartChrome(dates: model.points.map(\.date), values: model.points.map(\.value))
        .animation(.easeIn(duration: Elevation.bloomFade), value: model)
        .accessibilityLabel("Progression chart, Estimated 1RM in \(model.unit)")
    }
}

#Preview("Several Workouts") {
    let start = Calendar.current.startOfDay(for: .now)
    let points = [225.0, 232.5, 230.0, 240.0, 247.5].enumerated().map { offset, value in
        TrendPoint(date: Calendar.current.date(byAdding: .day, value: (offset - 4) * 4, to: start)!, value: value)
    }
    return ProgressionChart(model: .init(points: points, unit: "lbs"))
        .padding()
        .background(Color.surface)
}

#Preview("One Workout") {
    ProgressionChart(model: .init(points: [TrendPoint(date: .now, value: 225)], unit: "lbs"))
        .padding()
        .background(Color.surface)
}

#Preview("No Workouts") {
    ProgressionChart(model: .init(points: [], unit: "lbs"))
        .padding()
        .background(Color.surface)
}
