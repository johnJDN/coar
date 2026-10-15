import SwiftUI
import UIKit
import os

/// The weight screen, pushed from the Train root (`.scratch/health-pages/`). Three cards:
/// - Trend Weight as the hero (the raw value with a `—` trend caption while there is only
///   one point; `—` when there are none), a 1M / 3M / 1Y / All range, and the chart of raw
///   points and trend with the Goal Weight as a dashed rule;
/// - Progress: how fast Trend Weight is moving (a week, over the last four weeks), the Goal
///   Weight, and when it's reached at this pace; Set goal or Change goal;
/// - Weigh-ins: the latest five, each opening the log sheet for its Day, and All weigh-ins.
/// Reads through the façade on every appearance, after every log, and whenever the unit
/// changes. Deleting a weigh-in offers Undo.
final class BodyWeightViewController: ScreenViewController {

    private static let logger = Logger(category: "BodyWeight")
    static let recentCount = 5

    /// The chart's span.
    enum Range: Int, CaseIterable {
        case month, quarter, year, all

        var title: String {
            switch self {
            case .month: return "1M"
            case .quarter: return "3M"
            case .year: return "1Y"
            case .all: return "All"
            }
        }

        /// Days back from today, or nil for everything.
        var days: Int? {
            switch self {
            case .month: return 30
            case .quarter: return 91
            case .year: return 365
            case .all: return nil
            }
        }
    }

    private let dependencies: AppDependencies
    private let heroLabel = HeroNumberLabel()
    private let captionLabel = UILabel()
    private let rangeControl = UISegmentedControl(items: Range.allCases.map(\.title))
    private let chart = UIHostingController(rootView: BodyWeightChart(model: .init(raw: [], trend: [], unit: "")))
    private let rateRow = MetricRowView()
    private let goalRow = MetricRowView()
    private let progressCaption = UILabel()
    private lazy var goalButton = UIButton.inCardAction(title: "Set goal", systemImage: "flag.fill") { [weak self] in self?.editGoal() }
    private let weighInsStack = UIStackView()
    private let weighInsEmpty = UILabel()
    private lazy var allButton = UIButton.inCardAction(title: "All weigh-ins", systemImage: "list.bullet") { [weak self] in self?.showAll() }
    private let toast = ToastView()
    private var unitObservation: MassUnitObservation?
    private var range = Range.quarter

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: "Body Weight")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let log = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.presentLog(day: nil) })
        log.accessibilityLabel = "Log Body Weight"
        navigationItem.rightBarButtonItem = log

        for label in [captionLabel, progressCaption, weighInsEmpty] {
            label.font = UIFont.label
            label.textColor = UIColor.textSecondary
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
        }
        weighInsEmpty.text = "Weigh-ins you log show here."

        rangeControl.selectedSegmentIndex = range.rawValue
        rangeControl.addAction(UIAction { [weak self] _ in
            guard let self, let range = Range(rawValue: rangeControl.selectedSegmentIndex) else { return }
            self.range = range
            render()
        }, for: .valueChanged)

        chart.view.backgroundColor = .clear
        chart.sizingOptions = .intrinsicContentSize
        addChild(chart)

        let card = CardView()
        card.contentStack.addArrangedSubview(heroLabel)
        card.contentStack.addArrangedSubview(captionLabel)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: captionLabel)
        card.contentStack.addArrangedSubview(rangeControl)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: rangeControl)
        card.contentStack.addArrangedSubview(chart.view)
        contentStack.addArrangedSubview(card)
        chart.didMove(toParent: self)

        let progress = CardView(title: "Progress", systemImage: "chart.line.downtrend.xyaxis", iconTint: UIColor.accentTeal)
        progress.contentStack.addArrangedSubview(rateRow)
        progress.contentStack.addArrangedSubview(goalRow)
        progress.contentStack.addArrangedSubview(progressCaption)
        progress.contentStack.setCustomSpacing(Metrics.spaceInner, after: progressCaption)
        progress.contentStack.addArrangedSubview(UIStackView(arrangedSubviews: [goalButton, UIView()]))
        contentStack.addArrangedSubview(progress)

        weighInsStack.axis = .vertical
        weighInsStack.spacing = Metrics.spaceTight / 2
        let weighIns = CardView(title: "Weigh-ins", systemImage: "scalemass.fill", iconTint: UIColor.accentTeal)
        weighIns.contentStack.addArrangedSubview(weighInsStack)
        weighIns.contentStack.addArrangedSubview(weighInsEmpty)
        weighIns.contentStack.setCustomSpacing(Metrics.spaceInner, after: weighInsEmpty)
        weighIns.contentStack.addArrangedSubview(UIStackView(arrangedSubviews: [allButton, UIView()]))
        contentStack.addArrangedSubview(weighIns)

        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -Metrics.spaceEdge),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Metrics.spaceTight),
        ])

        unitObservation = dependencies.preferences.observeMassUnit { [weak self] in self?.render() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    // MARK: - Rendering

    private func render() {
        var records: [BodyWeightRecord] = []
        var goal: Double?
        do {
            records = try dependencies.store.bodyWeights()
            goal = try dependencies.store.goalWeight()
        } catch {
            Self.logger.error("Failed to read Body Weights: \(error, privacy: .public)")
        }
        let unit = dependencies.preferences.massUnit
        let trend = TrendWeight.series(of: records.map(\.kilograms))

        let caption: String
        if let latest = records.last {
            caption = trend.isEmpty
                ? "\(latest.day.shortText) · Trend —"
                : "Trend Weight · latest \(unit.displayText(fromKilograms: latest.kilograms)), \(latest.day.shortText)"
        } else {
            caption = "No Body Weight yet"
        }
        let hero = TrendWeight.hero(of: records.map(\.kilograms)).map { unit.displayText(fromKilograms: $0) }
        heroLabel.setValue(hero ?? "—", isEmpty: hero == nil)
        captionLabel.text = caption

        let start = range.days.map { Day.today().advanced(by: -$0) }
        let shown = records.indices.filter { start == nil || records[$0].day >= start! }
        let raw = shown.map { TrendPoint(date: records[$0].day.start(), value: unit.displayValue(fromKilograms: records[$0].kilograms)) }
        let smoothed = trend.isEmpty ? [] : shown.map { TrendPoint(date: records[$0].day.start(), value: unit.displayValue(fromKilograms: trend[$0])) }
        let goalValue = goal.map { unit.displayValue(fromKilograms: $0) }
        chart.rootView = BodyWeightChart(model: .init(raw: raw, trend: smoothed, unit: unit.symbol, goal: goalValue.flatMap { Self.inside($0, raw) }))

        renderProgress(records: records, trend: trend.last, goal: goal, unit: unit)
        renderWeighIns(records: records, unit: unit)
    }

    /// The goal when the chart's axis reaches it (the same padding `TrendChartChrome` uses),
    /// so a far-off goal doesn't flatten the line.
    private static func inside(_ goal: Double, _ points: [TrendPoint]) -> Double? {
        guard let low = points.map(\.value).min(), let high = points.map(\.value).max() else { return nil }
        let padding = max(1, (high - low) * 0.25)
        return (low - padding...high + padding).contains(goal) ? goal : nil
    }

    private func renderProgress(records: [BodyWeightRecord], trend: Double?, goal: Double?, unit: MassUnit) {
        let rate = TrendWeight.weeklyRate(of: records)
        let rateIcon = (rate ?? 0) < 0 ? "arrow.down.right" : (rate ?? 0) > 0 ? "arrow.up.right" : "arrow.right"
        rateRow.configure(leading: .symbol(rateIcon, tint: UIColor.accentTeal), title: "Last \(TrendWeight.rateWeeks) weeks",
                          value: rate.map { "\(Self.signed($0, unit)) a week" } ?? "—")
        goalRow.configure(leading: .symbol("flag.fill", tint: goal == nil ? UIColor.textTertiary : UIColor.accentTeal), title: "Goal",
                          value: goal.map { unit.displayText(fromKilograms: $0) } ?? "None")
        goalButton.configuration?.title = goal == nil ? "Set goal" : "Change goal"

        var lines: [String] = []
        if rate == nil {
            lines.append("The rate needs \(TrendWeight.minimumRateDays / 7) weeks of weigh-ins. It follows Trend Weight, so one heavy morning doesn't move it.")
        }
        if let goal, let trend {
            let left = unit.displayText(fromKilograms: abs(goal - trend))
            switch TrendWeight.progress(trend: trend, goal: goal, weeklyRate: rate) {
            case .reached: lines.append("You're at your goal.")
            case .toward(let weeks): lines.append("\(left) to go · \(Self.arrival(weeks: weeks)) at this pace.")
            case .away: lines.append("\(left) to go, but the trend is heading the other way.")
            case .steady: lines.append("\(left) to go, and the trend is steady.")
            case .unknown: lines.append("\(left) to go.")
            }
        } else if goal == nil {
            lines.append("A goal adds a line to the chart and an estimate of when you'll reach it.")
        }
        progressCaption.text = lines.joined(separator: " ")
    }

    /// "−0.6 lbs", "+0.2 kg".
    private static func signed(_ kilograms: Double, _ unit: MassUnit) -> String {
        let value = unit.displayValue(fromKilograms: abs(kilograms))
        let sign = value == 0 ? "" : kilograms < 0 ? "−" : "+"
        return "\(sign)\(value.formatted(.number.precision(.fractionLength(1)))) \(unit.symbol)"
    }

    /// "around Jan 10", "in about 3 months", "more than two years".
    private static func arrival(weeks: Double) -> String {
        guard weeks <= 104 else { return "more than two years away" }
        let date = Calendar.current.date(byAdding: .day, value: Int((weeks * 7).rounded()), to: Date())!
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return "around " + date.formatted(sameYear ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().year())
    }

    private func renderWeighIns(records: [BodyWeightRecord], unit: MassUnit) {
        weighInsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let recent = Array(records.suffix(Self.recentCount).reversed())
        for record in recent {
            let previous = records.last { $0.day < record.day }
            let row = WeighInRow()
            row.configure(record: record, previous: previous, unit: unit)
            row.addAction(UIAction { [weak self] _ in self?.presentLog(day: record.day) }, for: .touchUpInside)
            weighInsStack.addArrangedSubview(row)
        }
        weighInsEmpty.isHidden = !records.isEmpty
        allButton.superview?.isHidden = records.count <= Self.recentCount
        allButton.configuration?.title = "All \(records.count) weigh-ins"
    }

    // MARK: - Actions

    private func presentLog(day: Day?) {
        let sheet = BodyWeightLogViewController.sheet(dependencies: dependencies, day: day, onLogged: { [weak self] in self?.render() },
                                                      onDeleted: { [weak self] in self?.deleted($0) })
        present(sheet, animated: true)
    }

    private func showAll() {
        let history = BodyWeightHistoryViewController(dependencies: dependencies) { [weak self] in self?.render() }
        navigationController?.pushViewController(history, animated: true)
    }

    /// A weigh-in deleted from the log sheet: Undo puts it back, in Apple Health too.
    private func deleted(_ record: BodyWeightRecord) {
        render()
        toast.show("Deleted \(record.day.shortText)", actionTitle: "Undo") { [weak self] in
            guard let self else { return }
            let logger = BodyWeightLogger(store: dependencies.store, healthWriter: dependencies.bodyWeightWriter)
            Task {
                try? await logger.log(record.kilograms, in: .kilograms, on: record.day, stored: { self.render() })
            }
        }
    }

    private func editGoal() {
        let unit = dependencies.preferences.massUnit
        let current = (try? dependencies.store.goalWeight()) ?? nil
        let alert = UIAlertController(title: current == nil ? "Set goal" : "Change goal", message: "The Body Weight you're working toward, in \(unit.symbol).", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .decimalPad
            field.placeholder = unit.symbol
            field.text = current.map { unit.displayValueText(fromKilograms: $0) }
            field.accessibilityLabel = "Goal Weight in \(unit.symbol)"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if current != nil {
            alert.addAction(UIAlertAction(title: "Remove goal", style: .destructive) { [weak self] _ in self?.setGoal(nil) })
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, let value = Double(typed: text), value > 0 else { return }
            self?.setGoal(unit.kilograms(fromDisplayValue: value))
        })
        present(alert, animated: true)
    }

    private func setGoal(_ kilograms: Double?) {
        do {
            try dependencies.store.setGoalWeight(kilograms: kilograms)
        } catch {
            Self.logger.error("Failed to save Goal Weight: \(error, privacy: .public)")
        }
        render()
    }
}

/// One weigh-in as a tappable row: the Day, the weight, and the change from the one before.
final class WeighInRow: UIControl {

    private let row = MetricRowView()
    private let changeLabel = UILabel()

    init() {
        super.init(frame: .zero)
        changeLabel.font = UIFont.label
        changeLabel.textColor = UIColor.textTertiary
        changeLabel.adjustsFontForContentSizeCategory = true
        changeLabel.textAlignment = .right
        changeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        changeLabel.setContentHuggingPriority(.required, for: .horizontal)
        changeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [row, changeLabel])
        stack.spacing = Metrics.spaceTight
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(record: BodyWeightRecord, previous: BodyWeightRecord?, unit: MassUnit) {
        let title = record.day.start().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        row.configure(leading: .symbol("scalemass", tint: UIColor.textTertiary), title: title, value: unit.displayText(fromKilograms: record.kilograms))
        if let previous {
            let change = unit.displayValue(fromKilograms: record.kilograms) - unit.displayValue(fromKilograms: previous.kilograms)
            changeLabel.text = abs(change) < 0.05 ? "±0" : "\(change < 0 ? "−" : "+")\(abs(change).formatted(.number.precision(.fractionLength(1))))"
        } else {
            changeLabel.text = ""
        }
        accessibilityLabel = "\(title), \(unit.displayText(fromKilograms: record.kilograms))"
        accessibilityHint = "Opens the weigh-in"
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.5 : 1 }
    }
}
