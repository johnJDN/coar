import SwiftUI
import UIKit
import os

/// The Sleep or Steps detail, pushed from its Home square (`.scratch/health-pages/`). Three
/// cards, read live from Apple Health on every appearance and never stored (ADR 0002):
/// - the overview: the hero value for the current Day (`No data` when Health has none), the
///   30-day average, and one bar per Day with the target as a dashed rule; tapping a bar
///   picks that Day for the next card;
/// - Sleep: the picked Night (bedtime to wake time, and its stages when a Watch recorded
///   them), then the usual bedtime and wake time with the target;
/// - Steps: the last 7 Days against the 7 before with the target, then the picked Day by hour.
/// The target is the user's tracked Habit for the metric (`HealthTarget`); with none, Set a
/// target starts one. While the Apple Health prompt has never been shown, tapping the empty
/// value slot shows it.
final class HealthDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Health")
    static let dayCount = 30
    /// Nights the usual times are taken over.
    static let patternNights = 14

    private let dependencies: AppDependencies
    private let metric: HealthMetric

    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()
    private let chart: UIHostingController<DailyBarChart>

    private let dayDetailLabel = UILabel()
    private let dayLabel = UILabel()
    private let dayNoteLabel = UILabel()
    private let stages = UIHostingController(rootView: SleepStagesView(stages: [:]))
    private let hours = UIHostingController(rootView: HourlyBarChart(model: .init(hours: [:])))

    private let firstRow = MetricRowView()
    private let secondRow = MetricRowView()
    private let summaryCaption = UILabel()
    private let targetRow = MetricRowView()
    private let targetCaption = UILabel()
    private lazy var setTargetButton = UIButton.inCardAction(title: "Set a target", systemImage: "target") { [weak self] in self?.setTarget() }

    private var loadTask: Task<Void, Never>?
    private var hoursTask: Task<Void, Never>?
    private var status: HealthAccessStatus?
    /// Per Day in the metric's own units (seconds, or a count).
    private var values: [Day: Double] = [:]
    private var nights: [Day: SleepNightDetail] = [:]
    private var target: HealthTarget?
    /// The Day picked on the chart; nil for the current one.
    private var selected: Day?
    private var today = Day.today()

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
        for label in [captionLabel, summaryCaption, targetCaption, dayNoteLabel, dayDetailLabel] {
            label.font = UIFont.label
            label.textColor = UIColor.textSecondary
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
        }
        dayLabel.font = UIFont.metricNumber
        dayLabel.textColor = UIColor.textPrimary
        dayLabel.adjustsFontForContentSizeCategory = true
        dayLabel.numberOfLines = 0

        let overview = CardView(title: metric.periodCaption, systemImage: metric.systemImage, iconTint: metric.uiAccent)
        overview.contentStack.addArrangedSubview(heroLabel)
        overview.contentStack.addArrangedSubview(captionLabel)
        overview.contentStack.setCustomSpacing(Metrics.spaceInner, after: captionLabel)
        host(chart, in: overview.contentStack)

        let dayCard = CardView(title: metric == .sleep ? "Night" : "By hour", systemImage: metric == .sleep ? "moon.stars.fill" : "clock.fill", iconTint: metric.uiAccent, detail: dayDetailLabel)
        dayCard.contentStack.addArrangedSubview(dayLabel)
        if metric == .sleep {
            dayCard.contentStack.setCustomSpacing(Metrics.spaceInner, after: dayLabel)
            host(stages, in: dayCard.contentStack)
        } else {
            host(hours, in: dayCard.contentStack)
        }
        dayCard.contentStack.addArrangedSubview(dayNoteLabel)

        let summary = CardView(title: metric == .sleep ? "Usual times" : "This week", systemImage: metric == .sleep ? "clock.fill" : "calendar", iconTint: metric.uiAccent)
        for view in [firstRow, secondRow, summaryCaption, targetRow, targetCaption] as [UIView] {
            summary.contentStack.addArrangedSubview(view)
        }
        summary.contentStack.setCustomSpacing(Metrics.spaceInner, after: summaryCaption)
        let actions = UIStackView(arrangedSubviews: [setTargetButton, UIView()])
        summary.contentStack.addArrangedSubview(actions)

        contentStack.addArrangedSubview(overview)
        if metric == .sleep {
            contentStack.addArrangedSubview(dayCard)
            contentStack.addArrangedSubview(summary)
        } else {
            contentStack.addArrangedSubview(summary)
            contentStack.addArrangedSubview(dayCard)
        }

        render()
    }

    private func host<Content: View>(_ controller: UIHostingController<Content>, in stack: UIStackView) {
        controller.view.backgroundColor = .clear
        controller.sizingOptions = .intrinsicContentSize
        addChild(controller)
        stack.addArrangedSubview(controller.view)
        controller.didMove(toParent: self)
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
            var values: [Day: Double] = [:]
            var nights: [Day: SleepNightDetail] = [:]
            do {
                switch metric {
                case .sleep:
                    nights = try await dependencies.healthReader.sleepNights(wakingOn: Self.days(endingOn: today))
                    values = nights.mapValues(\.timeAsleep)
                case .steps:
                    values = try await metric.read(Self.days(endingOn: today), from: dependencies.healthReader)
                }
            } catch {
                Self.logger.error("Failed to read \(self.metric.title, privacy: .public) from Apple Health: \(error, privacy: .public)")
            }
            guard !Task.isCancelled else { return }
            self.today = today
            self.status = status
            self.values = values
            self.nights = nights
            target = HealthTarget.current(for: metric, store: dependencies.store, today: today)
            if let selected, values[selected] == nil { self.selected = nil }
            render()
            loadHours()
        }
    }

    /// The picked Day's steps by hour.
    private func loadHours() {
        guard metric == .steps else { return }
        hoursTask?.cancel()
        let day = selected ?? today
        hoursTask = Task { [weak self] in
            guard let self else { return }
            let hourly: [Int: Int]
            do {
                hourly = try await dependencies.healthReader.hourlySteps(on: day)
            } catch {
                Self.logger.error("Failed to read hourly steps from Apple Health: \(error, privacy: .public)")
                hourly = [:]
            }
            guard !Task.isCancelled else { return }
            hours.rootView = HourlyBarChart(model: .init(hours: hourly))
        }
    }

    private func connect() {
        Task {
            await dependencies.health.connect()
            load()
        }
    }

    private func select(_ date: Date?) {
        selected = date.map { Day($0) }
        if selected == today { selected = nil }
        render()
        loadHours()
    }

    private func setTarget() {
        let sheet = HabitFormViewController.sheet(dependencies: dependencies, kind: .tracked, metric: metric.trackedMetric) { [weak self] in self?.load() }
        present(sheet, animated: true)
    }

    // MARK: - Rendering

    private func render() {
        let current = values[today]
        let currentText = current.map(metric.text)
        heroLabel.setValue(currentText ?? "No data", isEmpty: currentText == nil)
        captionLabel.text = caption(current: current)

        let points = Self.days(endingOn: today).compactMap { day in
            values[day].map { TrendPoint(date: day.start(), value: metric.chartValue($0)) }
        }
        chart.rootView = DailyBarChart(
            model: .init(metric: metric, points: points, span: Self.span(endingOn: today), target: target?.amount, selected: selected?.start()),
            onSelect: { [weak self] in self?.select($0) }
        )

        switch metric {
        case .sleep: renderNight(); renderPattern()
        case .steps: renderStepsDay(); renderWeek()
        }
        renderTarget()
    }

    private func caption(current: Double?) -> String {
        if current == nil, status == .notRequested {
            return "Tap No data to connect Apple Health"
        }
        if status == .unavailable {
            return "Apple Health is not available on this device"
        }
        guard !values.isEmpty else {
            return status == nil ? "Reading Apple Health…" : "Nothing in Apple Health for the last \(Self.dayCount) days. \(metric.sourceHint)"
        }
        let average = values.values.reduce(0, +) / Double(values.count)
        return "\(Self.dayCount)-day average \(metric.text(average)) · tap a bar to see that \(metric == .sleep ? "night" : "day")"
    }

    /// The picked Night: its span, Time Asleep, and stages.
    private func renderNight() {
        let day = selected ?? today
        dayDetailLabel.text = day == today ? "Last night" : day.start().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        guard let night = nights[day] else {
            dayLabel.text = "No sleep recorded"
            dayLabel.textColor = UIColor.textTertiary
            stages.view.isHidden = true
            dayNoteLabel.isHidden = true
            return
        }
        dayLabel.textColor = UIColor.textPrimary
        let span = "\(night.fellAsleep.formatted(date: .omitted, time: .shortened)) – \(night.woke.formatted(date: .omitted, time: .shortened))"
        dayLabel.text = "\(span) · \(HealthText.duration(night.timeAsleep)) asleep"
        stages.rootView = SleepStagesView(stages: night.stages)
        stages.view.isHidden = night.stages.isEmpty
        dayNoteLabel.isHidden = !night.stages.isEmpty
        dayNoteLabel.text = "No stages for this night. An Apple Watch worn to bed records them."
    }

    /// Usual bedtime and wake time over the last two weeks.
    private func renderPattern() {
        let recent = nights.filter { $0.key > today.advanced(by: -Self.patternNights) }
        guard let pattern = SleepPattern.from(recent, in: .current) else {
            firstRow.configure(leading: .symbol("moon.fill", tint: metric.uiAccent), title: "Asleep around", value: "—")
            secondRow.configure(leading: .symbol("sun.max.fill", tint: metric.uiAccent), title: "Up around", value: "—")
            summaryCaption.text = "Needs \(SleepPattern.minimumNights) nights of sleep data from the last \(Self.patternNights)."
            return
        }
        firstRow.configure(leading: .symbol("moon.fill", tint: metric.uiAccent), title: "Asleep around",
                           value: "\(SleepPattern.clockText(minutesAfterSixPM: pattern.bedtime)) \(SleepPattern.spreadText(pattern.bedtimeSpread))")
        secondRow.configure(leading: .symbol("sun.max.fill", tint: metric.uiAccent), title: "Up around",
                            value: "\(SleepPattern.clockText(minutesAfterSixPM: pattern.wake)) \(SleepPattern.spreadText(pattern.wakeSpread))")
        summaryCaption.text = "From the last \(pattern.nights) nights. The ± is how far a typical night strays: smaller is steadier."
    }

    /// The picked Day's total; its hours load separately.
    private func renderStepsDay() {
        let day = selected ?? today
        dayDetailLabel.text = day.shortTitle(relativeTo: today)
        if let steps = values[day] {
            dayLabel.text = "\(metric.text(steps)) steps"
            dayLabel.textColor = UIColor.textPrimary
        } else {
            dayLabel.text = "No steps recorded"
            dayLabel.textColor = UIColor.textTertiary
        }
        dayNoteLabel.isHidden = true
    }

    /// The last 7 full Days against the 7 before.
    private func renderWeek() {
        guard let week = HealthSummary.week(values, today: today) else {
            firstRow.configure(leading: .symbol("calendar", tint: metric.uiAccent), title: "Last 7 days", value: "—")
            secondRow.isHidden = true
            summaryCaption.text = "Averages leave out today, which isn't over yet."
            return
        }
        firstRow.configure(leading: .symbol("calendar", tint: metric.uiAccent), title: "Last 7 days", value: "\(metric.text(week.recent)) a day")
        secondRow.isHidden = week.previous == nil
        if let previous = week.previous {
            secondRow.configure(leading: .symbol("calendar", tint: UIColor.textTertiary), title: "Week before", value: "\(metric.text(previous)) a day")
            summaryCaption.text = "\(HealthSummary.changeText(from: previous, to: week.recent).capitalizedFirst). Averages leave out today, which isn't over yet."
        } else {
            summaryCaption.text = "Averages leave out today, which isn't over yet."
        }
    }

    /// The target from the tracked Habit, and how often it was met.
    private func renderTarget() {
        guard let target else {
            targetRow.configure(leading: .symbol("target", tint: UIColor.textTertiary), title: "Target", value: "None")
            targetCaption.text = "A tracked \(metric.title) habit sets the line on the chart and counts the \(metric == .sleep ? "nights" : "days") you meet it."
            setTargetButton.superview?.isHidden = false
            return
        }
        setTargetButton.superview?.isHidden = true
        let unit = metric == .sleep ? "a night" : "a day"
        targetRow.configure(leading: .symbol("target", tint: metric.uiAccent), title: "Target", value: "\(targetText(target.amount)) \(unit)")
        // Last night is over; today's steps aren't, so Steps counts back from yesterday.
        let span = metric == .sleep ? 7 : Self.dayCount
        let days = (1...span).map { today.advanced(by: metric == .sleep ? 1 - $0 : -$0) }
        let chartValues = values.mapValues(metric.chartValue)
        let record = HealthSummary.target(target.amount, values: chartValues, days: days, today: today)
        let noun = metric == .sleep ? "nights" : "days"
        var text = "Met \(record.met) of the last \(span) \(noun)"
        if record.judged < span { text += " (\(record.judged) with data)" }
        if record.inARow > 1 { text += " · \(record.inARow) in a row" }
        targetCaption.text = "\(text). From your “\(target.habitName)” habit."
    }

    private func targetText(_ amount: Double) -> String {
        metric == .sleep ? HealthText.duration(amount * 3_600) : HealthText.steps(Int(amount.rounded()))
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
