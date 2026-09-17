import Charts
import SwiftUI

/// A sleep or steps detail chart (DESIGN.md §8 "One value per Day"): one bar per Day that
/// has a value, in the metric's accent, the latest bar saturated with bloom and earlier ones
/// muted; Days without data leave a gap; no gridlines, no legend, axis labels in
/// `textTertiary`; `No data` alone in the slot when nothing in the span has a value. A
/// SwiftUI leaf: values in, nothing out (ADR 0001).
struct DailyBarChart: View {

    struct Model: Equatable {
        var metric: HealthMetric
        /// One point per Day with a value, in chart units, in Day order.
        var points: [TrendPoint]
        /// The whole span the bars sit in, so a sparse month still reads as a month.
        var span: ClosedRange<Date>
    }

    let model: Model

    @Environment(\.colorScheme) private var colorScheme

    private static let mutedOpacity = 0.7

    private var valueDomain: ClosedRange<Double> {
        0...max(1, (model.points.map(\.value).max() ?? 0) * 1.1)
    }

    var body: some View {
        Chart {
            ForEach(model.points.dropLast()) { point in
                BarMark(x: .value("Day", point.date, unit: .day), y: .value(model.metric.title, point.value))
                    .foregroundStyle(model.metric.accentColor.opacity(Self.mutedOpacity))
                    .cornerRadius(3)
            }
            if let last = model.points.last {
                BarMark(x: .value("Day", last.date, unit: .day), y: .value(model.metric.title, last.value))
                    .foregroundStyle(model.metric.accentColor)
                    .cornerRadius(3)
                    .bloom(model.metric.accentColor, in: colorScheme)
            }
        }
        .chartXAxis(model.points.isEmpty ? .hidden : .automatic)
        .chartYAxis(model.points.isEmpty ? .hidden : .automatic)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                if let number = value.as(Double.self) {
                    AxisValueLabel {
                        Text(model.metric.axisText(number))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .chartXScale(domain: model.span, range: .plotDimension(startPadding: 4, endPadding: 24))
        .chartYScale(domain: valueDomain)
        .overlay {
            if model.points.isEmpty {
                Text("No data")
                    .font(Font.bodyText)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(height: TrendChartChrome.height)
        .animation(.easeIn(duration: Elevation.bloomFade), value: model)
        .accessibilityLabel("\(model.metric.title) for the last 30 days")
    }
}

#Preview("Sleep") {
    let today = Day.today()
    let hours = [7.2, 6.8, 7.9, 0, 6.1, 7.4, 8.2, 7.0, 6.5, 7.7, 7.1, 6.9, 8.0, 7.3]
    let points = hours.enumerated().compactMap { offset, value in
        value == 0 ? nil : TrendPoint(date: today.advanced(by: offset - 13).start(), value: value)
    }
    return DailyBarChart(model: .init(metric: .sleep, points: points, span: today.advanced(by: -29).start()...today.advanced(by: 1).start()))
        .padding()
        .background(Color.surface)
}

#Preview("No data") {
    let today = Day.today()
    return DailyBarChart(model: .init(metric: .steps, points: [], span: today.advanced(by: -29).start()...today.advanced(by: 1).start()))
        .padding()
        .background(Color.surface)
}
