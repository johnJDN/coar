import Charts
import SwiftUI

/// A sleep or steps detail chart (DESIGN.md §8 "One value per Day"): one bar per Day that
/// has a value, in the metric's accent, the chosen bar (the latest unless one was tapped)
/// saturated with bloom and the others muted; Days without data leave a gap; a target, when
/// there is one, as a dashed `textTertiary` rule; no gridlines, no legend, axis labels in
/// `textTertiary`; `No data` alone in the slot when nothing in the span has a value. A
/// SwiftUI leaf: values in, a tapped Day out (ADR 0001).
struct DailyBarChart: View {

    struct Model: Equatable {
        var metric: HealthMetric
        /// One point per Day with a value, in chart units, in Day order.
        var points: [TrendPoint]
        /// The whole span the bars sit in, so a sparse month still reads as a month.
        var span: ClosedRange<Date>
        /// The target in chart units, drawn as a rule.
        var target: Double? = nil
        /// The tapped Day's start; nil for the latest.
        var selected: Date? = nil
    }

    let model: Model
    /// A bar's Day start when tapped; nil when the chosen bar is tapped again.
    var onSelect: (Date?) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme

    private static let mutedOpacity = 0.7

    private var valueDomain: ClosedRange<Double> {
        0...max(1, max(model.points.map(\.value).max() ?? 0, model.points.isEmpty ? 0 : model.target ?? 0) * 1.1)
    }

    /// The bar drawn saturated: the tapped one, or the latest.
    private var chosen: TrendPoint? {
        model.points.first { $0.date == model.selected } ?? model.points.last
    }

    var body: some View {
        Chart {
            ForEach(model.points.filter { $0 != chosen }) { point in
                BarMark(x: .value("Day", point.date, unit: .day), y: .value(model.metric.title, point.value))
                    .foregroundStyle(model.metric.accent.opacity(Self.mutedOpacity))
                    .cornerRadius(3)
            }
            if let chosen {
                BarMark(x: .value("Day", chosen.date, unit: .day), y: .value(model.metric.title, chosen.value))
                    .foregroundStyle(model.metric.accent)
                    .cornerRadius(3)
                    .bloom(model.metric.accent, in: colorScheme)
            }
            if let target = model.target, !model.points.isEmpty {
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(Color.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let frame = proxy.plotFrame.map({ geometry[$0] }),
                              let date: Date = proxy.value(atX: location.x - frame.origin.x) else { return }
                        let day = Calendar.current.startOfDay(for: date)
                        guard model.points.contains(where: { $0.date == day }) else { return }
                        onSelect(day == chosen?.date && model.selected != nil ? nil : day)
                    }
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
    return DailyBarChart(model: .init(metric: .sleep, points: points, span: HealthDetailViewController.span(endingOn: today)))
        .padding()
        .background(Color.surface)
}

#Preview("No data") {
    let today = Day.today()
    return DailyBarChart(model: .init(metric: .steps, points: [], span: HealthDetailViewController.span(endingOn: today)))
        .padding()
        .background(Color.surface)
}
