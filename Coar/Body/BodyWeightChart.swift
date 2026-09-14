import Charts
import SwiftUI

/// The weight screen's chart (DESIGN.md §8 "Trend over time"): raw Body Weights as muted
/// points, Trend Weight as a 2pt accent line with bloom on its last point, no gridlines,
/// axis labels in `textTertiary`. A SwiftUI leaf: values in, nothing out (ADR 0001).
struct BodyWeightChart: View {

    struct Point: Hashable, Identifiable {
        let date: Date
        /// In the display unit.
        let value: Double
        var id: Date { date }
    }

    struct Model: Equatable {
        var raw: [Point]
        var trend: [Point]
        var unit: String
    }

    let model: Model

    @Environment(\.colorScheme) private var colorScheme

    /// About four date labels however long the series is.
    private var dayStride: Int {
        guard let first = model.raw.first?.date, let last = model.raw.last?.date else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return max(1, Int((Double(days) / 4).rounded(.up)))
    }

    /// The data's range with breathing room, so a flat or single-point series still reads
    /// as a sensible axis rather than a degenerate one.
    private var valueDomain: ClosedRange<Double> {
        let values = model.raw.map(\.value)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let padding = max(1, (high - low) * 0.25)
        return (low - padding)...(high + padding)
    }

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
                    .shadow(color: Color.accentTeal.opacity(Elevation.bloomOpacity(for: colorScheme == .dark ? .dark : .light)), radius: 6)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: dayStride)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .chartYScale(domain: valueDomain)
        .chartXScale(range: .plotDimension(startPadding: 4, endPadding: 24))
        .overlay {
            if model.raw.isEmpty {
                Text("No data")
                    .font(Font.bodyText)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(height: 180)
        .animation(.easeIn(duration: Elevation.bloomFade), value: model)
        .accessibilityLabel("Body Weight chart in \(model.unit)")
    }
}

#Preview {
    let start = Calendar.current.startOfDay(for: .now)
    let raw = [185.3, 186.1, 184.8, 185.9, 184.2, 184.6, 183.9].enumerated().map { offset, value in
        BodyWeightChart.Point(date: Calendar.current.date(byAdding: .day, value: offset - 6, to: start)!, value: value)
    }
    let trend = zip(raw, TrendWeight.series(of: raw.map(\.value))).map { BodyWeightChart.Point(date: $0.date, value: $1) }
    return BodyWeightChart(model: .init(raw: raw, trend: trend, unit: "lbs"))
        .padding()
        .background(Color.surface)
}
