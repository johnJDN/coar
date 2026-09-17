import SwiftUI
import UIKit
import os

/// The 30-day Sleep or Steps detail, pushed from its Home square. One card: the hero value
/// for the current Day (`No data` when Health has none), a caption with the 30-day average,
/// and one bar per Day. Read live from Apple Health on every appearance and never stored
/// (ADR 0002). While the Apple Health prompt has never been shown, tapping the empty value
/// slot shows it.
final class HealthDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Health")
    static let dayCount = 30

    private let dependencies: AppDependencies
    private let metric: HealthMetric
    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()
    private let chart: UIHostingController<DailyBarChart>
    private var loadTask: Task<Void, Never>?

    init(dependencies: AppDependencies, metric: HealthMetric) {
        self.dependencies = dependencies
        self.metric = metric
        let today = Day.today()
        chart = UIHostingController(rootView: DailyBarChart(model: .init(metric: metric, points: [], span: Self.span(endingOn: today))))
        super.init(title: metric.title)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.subtitle = "Last \(Self.dayCount) days"

        heroLabel.onTapEmpty = { [weak self] in self?.connect() }

        captionLabel.font = UIFont.label
        captionLabel.textColor = UIColor.textSecondary
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.numberOfLines = 0

        chart.view.backgroundColor = .clear
        chart.sizingOptions = .intrinsicContentSize
        addChild(chart)

        let card = CardView(title: metric.periodCaption, systemImage: metric.systemImage, iconTint: metric.accent)
        card.contentStack.addArrangedSubview(heroLabel)
        card.contentStack.addArrangedSubview(captionLabel)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: captionLabel)
        card.contentStack.addArrangedSubview(chart.view)
        contentStack.addArrangedSubview(card)
        chart.didMove(toParent: self)

        render(status: nil, values: [:], today: Day.today())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    // MARK: - Reading

    /// The Days the detail covers, ending today.
    static func days(endingOn today: Day) -> [Day] {
        (0..<dayCount).map { today.advanced(by: $0 - (dayCount - 1)) }
    }

    /// The chart's span: the first Day's start to the end of today.
    static func span(endingOn today: Day) -> ClosedRange<Date> {
        today.advanced(by: -(dayCount - 1)).start()...today.advanced(by: 1).start()
    }

    private func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let today = Day.today()
            let status = await dependencies.health.status()
            let values: [Day: Double]
            do {
                values = try await metric.read(Self.days(endingOn: today), from: dependencies.healthReader)
            } catch {
                Self.logger.error("Failed to read \(self.metric.title, privacy: .public) from Apple Health: \(error, privacy: .public)")
                values = [:]
            }
            guard !Task.isCancelled else { return }
            render(status: status, values: values, today: today)
        }
    }

    private func connect() {
        Task {
            do {
                try await dependencies.health.requestAccess()
            } catch {
                Self.logger.error("HealthKit authorisation failed: \(error, privacy: .public)")
            }
            load()
        }
    }

    // MARK: - Rendering

    private func render(status: HealthAccessStatus?, values: [Day: Double], today: Day) {
        let current = values[today]
        let currentText = current.map(metric.text)
        heroLabel.setValue(currentText ?? "No data", isEmpty: currentText == nil)
        captionLabel.text = caption(status: status, values: values, current: current)

        let points = Self.days(endingOn: today).compactMap { day in
            values[day].map { TrendPoint(date: day.start(), value: metric.chartValue($0)) }
        }
        chart.rootView = DailyBarChart(model: .init(metric: metric, points: points, span: Self.span(endingOn: today)))
    }

    private func caption(status: HealthAccessStatus?, values: [Day: Double], current: Double?) -> String {
        if current == nil, status == .notRequested {
            return "Tap No data to connect Apple Health"
        }
        if status == .unavailable {
            return "Apple Health is not available on this device"
        }
        guard !values.isEmpty else {
            return status == nil ? "Reading Apple Health…" : "Nothing in Apple Health for the last \(Self.dayCount) days. Check Coar's access in the Health app."
        }
        let average = values.values.reduce(0, +) / Double(values.count)
        return "\(Self.dayCount)-day average \(metric.text(average))"
    }
}
