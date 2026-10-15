import Charts
import SwiftUI
import UIKit

/// A metric's history (`.scratch/health-pages/issues/03`; ADR 0001: SwiftUI leaf, values in,
/// nothing out): a W / M / 6M / Y segmented control, the range's average (or the scrubbed
/// point's value and date) as the hero, and the chart. Drag across the chart to scrub: a
/// rule follows the finger and the header shows that point; lifting goes back to the
/// average. Bars for daily totals, a line through points for readings, with the usual range
/// as a band behind an overnight reading's line (DESIGN.md §8).
struct MetricHistoryView: View {

    let metric: HistoryMetric
    /// A year of values per Day; nil while reading.
    let daily: [Day: Double]?
    let today: Day

    @State private var range: HistoryRange = .month
    @State private var scrubbed: Date?
    @Environment(\.colorScheme) private var colorScheme

    private var points: [HistoryPoint] {
        daily.map { MetricHistory.points($0, range: range, today: today) } ?? []
    }

    private var band: ClosedRange<Double>? {
        guard metric.showsUsualBand, let daily else { return nil }
        return MetricHistory.usualBand(daily, today: today)
    }

    /// The point under the finger: the last one starting at or before it.
    private var selected: HistoryPoint? {
        guard let scrubbed else { return nil }
        return points.last { $0.date <= scrubbed } ?? points.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spaceInner) {
                Picker("Range", selection: $range) {
                    ForEach(HistoryRange.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: Metrics.spaceInner) {
                    header
                    chart
                }
                .padding(Metrics.spaceInner)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: Metrics.radiusCard, style: .continuous))

                Text(footnote)
                    .font(Font.label)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(.horizontal, Metrics.spaceEdge)
            .padding(.vertical, Metrics.spaceCard)
        }
        .background(Color.background)
        .onChange(of: range) { _, _ in scrubbed = nil }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(Font.label)
                .foregroundStyle(Color.textSecondary)
            Text(headline)
                .font(Font.heroNumber)
                .foregroundStyle(daily == nil || points.isEmpty ? Color.textTertiary : Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
            Text(dates)
                .font(Font.label)
                .foregroundStyle(Color.textTertiary)
        }
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    private var caption: String {
        if let selected {
            return range.bucket == .day ? metric.title.uppercased() : "\(metric.title.uppercased()) · AVERAGE A DAY"
        }
        return range.bucket == .day && range == .week ? "AVERAGE" : "AVERAGE A DAY"
    }

    private var headline: String {
        guard let daily else { return "Reading…" }
        if let selected { return metric.text(selected.value) }
        return MetricHistory.average(daily, range: range, today: today).map(metric.text) ?? "No data"
    }

    private var dates: String {
        let calendar = Calendar.current
        if let selected {
            switch range.bucket {
            case .day: return selected.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            case .weekOfYear:
                let end = calendar.date(byAdding: .day, value: 6, to: selected.date)!
                return "Week of \(selected.date.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day())) · \(selected.count) \(selected.count == 1 ? "day" : "days") with data"
            default: return "\(selected.date.formatted(.dateTime.month(.wide).year())) · \(selected.count) \(selected.count == 1 ? "day" : "days") with data"
            }
        }
        let first = today.advanced(by: 1 - range.days).start()
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(today.start().formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private var footnote: String {
        var text = "Drag across the chart to see each \(range.bucketNoun)."
        if metric.showsUsualBand {
            text += band == nil
                ? " The shaded usual range appears once there are \(OvernightVitals.minimumNights) nights of readings."
                : " The shaded band is your usual range: the last 30 nights, give or take a typical night's difference."
        }
        if case .sleepScore = metric {
            text += " Coar's own score; Apple doesn't share theirs."
        }
        return text
    }

    // MARK: - Chart

    private var valueDomain: ClosedRange<Double> {
        let values = points.map(\.value) + (band.map { [$0.lowerBound, $0.upperBound] } ?? [])
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        if metric.isBars { return 0...max(1, high * 1.15) }
        let padding = max(1, (high - low) * 0.25)
        return (low - padding)...(high + padding)
    }

    private var chart: some View {
        let span = MetricHistory.span(range, today: today)
        return Chart {
            if let band {
                RectangleMark(xStart: .value("Start", span.lowerBound), xEnd: .value("End", span.upperBound),
                              yStart: .value("Usual low", band.lowerBound), yEnd: .value("Usual high", band.upperBound))
                    .foregroundStyle(metric.accent.opacity(0.12))
            }
            ForEach(points) { point in
                let emphasised = selected == nil ? point == points.last : point == selected
                if metric.isBars {
                    BarMark(x: .value("Date", point.date, unit: range.bucket), y: .value(metric.title, point.value))
                        .foregroundStyle(metric.accent.opacity(emphasised ? 1 : 0.6))
                        .cornerRadius(3)
                } else {
                    LineMark(x: .value("Date", point.date), y: .value(metric.title, point.value))
                        .foregroundStyle(metric.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", point.date), y: .value(metric.title, point.value))
                        .foregroundStyle(metric.accent)
                        .symbolSize(emphasised ? 56 : 16)
                }
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date, unit: metric.isBars ? range.bucket : .second))
                    .foregroundStyle(Color.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXSelection(value: $scrubbed)
        .chartXScale(domain: span)
        .chartYScale(domain: valueDomain)
        .chartXAxis(points.isEmpty ? .hidden : .automatic)
        .chartYAxis(points.isEmpty ? .hidden : .automatic)
        .chartXAxis {
            AxisMarks(values: axisDates(span)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel(axisLabel(date)).foregroundStyle(Color.textTertiary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                if let number = value.as(Double.self) {
                    AxisValueLabel { Text(metric.axisText(number)).foregroundStyle(Color.textTertiary) }
                }
            }
        }
        .overlay {
            if daily != nil, points.isEmpty {
                Text("No data").font(Font.bodyText).foregroundStyle(Color.textTertiary)
            }
        }
        .frame(height: 240)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityLabel("\(metric.title) chart")
        .accessibilityValue(headline)
    }

    /// About five dates along the bottom.
    private func axisDates(_ span: ClosedRange<Date>) -> [Date] {
        let calendar = Calendar.current
        let step: (Calendar.Component, Int) = switch range {
        case .week: (.day, 1)
        case .month: (.day, 7)
        case .halfYear: (.month, 1)
        case .year: (.month, 2)
        }
        var dates: [Date] = []
        var date = range == .month ? today.advanced(by: 1 - range.days).start() : span.lowerBound
        if range == .halfYear || range == .year {
            date = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            if date < span.lowerBound { date = calendar.date(byAdding: .month, value: 1, to: date)! }
        }
        while date < span.upperBound {
            dates.append(date)
            date = calendar.date(byAdding: step.0, value: step.1, to: date)!
        }
        return dates
    }

    private func axisLabel(_ date: Date) -> String {
        switch range {
        case .week: return date.formatted(.dateTime.weekday(.narrow))
        case .month: return date.formatted(.dateTime.month(.abbreviated).day())
        case .halfYear, .year: return date.formatted(.dateTime.month(.abbreviated))
        }
    }
}

/// The history page for one metric, pushed from the Sleep or Steps page. Reads a year once
/// and lets the view group it per range.
final class MetricHistoryViewController: UIHostingController<MetricHistoryView> {

    private let dependencies: AppDependencies
    private let metric: HistoryMetric
    private var loadTask: Task<Void, Never>?

    init(dependencies: AppDependencies, metric: HistoryMetric) {
        self.dependencies = dependencies
        self.metric = metric
        super.init(rootView: MetricHistoryView(metric: metric, daily: nil, today: .today()))
        title = metric.title
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let today = Day.today()
            let daily = (try? await MetricHistory.load(metric, dependencies: dependencies, today: today)) ?? [:]
            guard !Task.isCancelled else { return }
            rootView = MetricHistoryView(metric: metric, daily: daily, today: today)
        }
    }
}
