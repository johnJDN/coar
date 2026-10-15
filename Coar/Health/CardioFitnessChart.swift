import Charts
import SwiftUI

/// VO2 max over the last year (DESIGN.md §8 "Trend over time"): the Watch's estimates as a 2pt
/// amber line with bloom on the latest, no gridlines, axis labels in `textTertiary`. A SwiftUI
/// leaf: values in, nothing out (ADR 0001).
struct CardioFitnessChart: View {

    let points: [TrendPoint]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Day", point.date), y: .value("VO2 max", point.value))
                    .foregroundStyle(Color.accentAmber)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let last = points.last {
                PointMark(x: .value("Day", last.date), y: .value("VO2 max", last.value))
                    .foregroundStyle(Color.accentAmber)
                    .symbolSize(56)
                    .bloom(Color.accentAmber, in: colorScheme)
            }
        }
        .trendChartChrome(over: points)
        .animation(.easeIn(duration: Elevation.bloomFade), value: points)
        .accessibilityLabel("VO2 max over the last year")
    }
}
