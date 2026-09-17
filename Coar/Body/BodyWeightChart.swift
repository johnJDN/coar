import Charts
import SwiftUI

/// The weight screen's chart (DESIGN.md §8 "Trend over time"): raw Body Weights as muted
/// points, Trend Weight as a 2pt accent line with bloom on its last point, no gridlines,
/// axis labels in `textTertiary`. A SwiftUI leaf: values in, nothing out (ADR 0001).
struct BodyWeightChart: View {

    struct Model: Equatable {
        var raw: [TrendPoint]
        var trend: [TrendPoint]
        var unit: String
    }

    let model: Model

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Chart {
            ForEach(model.raw) { point in
                PointMark(x: .value("Day", point.date), y: .value("Body Weight", point.value))
                    .foregroundStyle(Color.accentTeal.opacity(0.35))
                    .symbolSize(24)
            }
            ForEach(model.trend) { point in
                LineMark(x: .value("Day", point.date), y: .value("Trend Weight", point.value))
                    .foregroundStyle(Color.accentTeal)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }
            if let last = model.trend.last {
                PointMark(x: .value("Day", last.date), y: .value("Trend Weight", last.value))
                    .foregroundStyle(Color.accentTeal)
                    .symbolSize(56)
                    .bloom(Color.accentTeal, in: colorScheme)
            }
        }
        .trendChartChrome(dates: model.raw.map(\.date), values: model.raw.map(\.value))
        .animation(.easeIn(duration: Elevation.bloomFade), value: model)
        .accessibilityLabel("Body Weight chart in \(model.unit)")
    }
}

#Preview {
    let start = Calendar.current.startOfDay(for: .now)
    let raw = [185.3, 186.1, 184.8, 185.9, 184.2, 184.6, 183.9].enumerated().map { offset, value in
        TrendPoint(date: Calendar.current.date(byAdding: .day, value: offset - 6, to: start)!, value: value)
    }
    let trend = zip(raw, TrendWeight.series(of: raw.map(\.value))).map { TrendPoint(date: $0.date, value: $1) }
    return BodyWeightChart(model: .init(raw: raw, trend: trend, unit: "lbs"))
        .padding()
        .background(Color.surface)
}
