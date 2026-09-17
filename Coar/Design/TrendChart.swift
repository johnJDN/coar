import Charts
import SwiftUI

/// One point of a trend chart (DESIGN.md §8 "Trend over time"), already in the display unit.
struct TrendPoint: Hashable, Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// The chrome every trend chart shares (DESIGN.md §8): about four date labels along the
/// bottom (the end ones pulled inward so none truncates) and three values on the trailing
/// edge, all in `textTertiary`; no gridlines; the value axis padded so a flat or
/// single-point series still reads as an axis; `No data` alone in the slot, no axes, when
/// the series is empty; a fixed height.
struct TrendChartChrome: ViewModifier {
    let points: [TrendPoint]

    private var dates: [Date] { points.map(\.date) }
    private var values: [Double] { points.map(\.value) }

    static let height: CGFloat = 180

    /// About four date labels however long the series is.
    private var dayStride: Int {
        guard let first = dates.first, let last = dates.last else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return max(1, Int((Double(days) / 4).rounded(.up)))
    }

    /// The series' span; a single point (or none) gets a day either side so the axis has
    /// somewhere to put its labels.
    private var dateDomain: ClosedRange<Date> {
        guard let first = dates.first, let last = dates.last, first < last else {
            let only = dates.first ?? Date()
            return Calendar.current.date(byAdding: .day, value: -1, to: only)!...Calendar.current.date(byAdding: .day, value: 1, to: only)!
        }
        return first...last
    }

    /// The data's range with breathing room, so a flat or single-point series still reads
    /// as a sensible axis rather than a degenerate one.
    private var valueDomain: ClosedRange<Double> {
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        let padding = max(1, (high - low) * 0.25)
        return (low - padding)...(high + padding)
    }

    func body(content: Content) -> some View {
        content
            .chartXAxis(dates.isEmpty ? .hidden : .automatic)
            .chartYAxis(dates.isEmpty ? .hidden : .automatic)
            .chartXAxis {
                AxisMarks(preset: .aligned, values: .stride(by: .day, count: dayStride)) { _ in
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
            .chartXScale(domain: dateDomain, range: .plotDimension(startPadding: 4, endPadding: 24))
            .overlay {
                if dates.isEmpty {
                    Text("No data")
                        .font(Font.bodyText)
                        .foregroundStyle(Color.textTertiary)
                }
            }
            .frame(height: Self.height)
    }
}

extension View {
    /// The DESIGN.md §8 trend-chart chrome over the series the chart draws.
    func trendChartChrome(over points: [TrendPoint]) -> some View {
        modifier(TrendChartChrome(points: points))
    }
}

extension ChartContent {
    /// Bloom (DESIGN.md §6) on an active chart point: the accent as a soft shadow, lower in
    /// light mode.
    func bloom(_ accent: Color, in colorScheme: ColorScheme) -> some ChartContent {
        shadow(color: accent.opacity(Elevation.bloomOpacity(for: colorScheme == .dark ? .dark : .light)), radius: 6)
    }
}
