import Charts
import SwiftUI
import UIKit
import os

/// Indoor walks compared (`.scratch/walks/issues/01`; a pure rule): heart rate is comparable only
/// between walks at the same treadmill speed and incline, so walks are grouped by those, and
/// each group says its average heart rate with and without the inhaler, and its first and
/// latest walk.
enum WalkComparison {

    struct Group: Equatable {
        /// "3.0 mph · 6%".
        let settings: String
        let count: Int
        let withInhaler: (average: Double, count: Int)?
        let without: (average: Double, count: Int)?
        let first: Double
        let latest: Double

        static func == (lhs: Group, rhs: Group) -> Bool {
            lhs.settings == rhs.settings && lhs.count == rhs.count && lhs.first == rhs.first && lhs.latest == rhs.latest
                && lhs.withInhaler?.average == rhs.withInhaler?.average && lhs.without?.average == rhs.without?.average
        }
    }

    /// Walks with a heart rate and both settings, grouped; the largest groups first.
    static func groups(_ walks: [(workout: HealthWorkout, note: WorkoutNoteRecord?)]) -> [Group] {
        let usable = walks.compactMap { walk -> (key: String, heart: Double, inhaler: Bool, start: Date)? in
            guard let heart = walk.workout.averageHeartRate, let settings = walk.note?.settingsText else { return nil }
            return (settings, heart, walk.note?.usedInhaler ?? false, walk.workout.start)
        }
        return Dictionary(grouping: usable, by: \.key).map { key, group in
            let sorted = group.sorted { $0.start < $1.start }
            func average(_ walks: [(key: String, heart: Double, inhaler: Bool, start: Date)]) -> (Double, Int)? {
                walks.isEmpty ? nil : (walks.map(\.heart).reduce(0, +) / Double(walks.count), walks.count)
            }
            return Group(settings: key, count: group.count, withInhaler: average(group.filter(\.inhaler)), without: average(group.filter { !$0.inhaler }),
                         first: sorted.first!.heart, latest: sorted.last!.heart)
        }
        .sorted { ($0.count, $0.settings) > ($1.count, $1.settings) }
    }
}

/// A Watch workout's note (ADR 0001: SwiftUI leaf, values in, closures out): what it was, then
/// the inhaler, and a treadmill's speed and incline. Saved as it changes.
struct WorkoutNoteForm: View {

    let workout: HealthWorkout
    @State var note: WorkoutNoteRecord
    /// The last speed and incline set on any walk, offered while this one has neither.
    var last: (speedKmh: Double, inclinePercent: Double)?
    let onChange: (WorkoutNoteRecord) -> Void

    var body: some View {
        Form {
            Section {
                row("When", "\(workout.start.formatted(date: .abbreviated, time: .shortened)) · \(HealthText.duration(workout.duration))")
                if let heart = workout.averageHeartRate { row("Average heart rate", "\(Int(heart.rounded())) bpm") }
                if let meters = workout.distanceMeters, meters > 0 { row("Distance (Watch)", Self.distance(meters)) }
            }
            Section {
                Toggle("Used inhaler before", isOn: $note.usedInhaler)
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.accentLavender)
                    .formRow()
                numberRow("Speed", unit: TreadmillSpeed.unit, value: Binding(
                    get: { note.speedKmh.map(TreadmillSpeed.display) },
                    set: { note.speedKmh = $0.map(TreadmillSpeed.kmh(fromDisplay:)) }
                ))
                numberRow("Incline", unit: "%", value: $note.inclinePercent)
                if let last, note.speedKmh == nil, note.inclinePercent == nil {
                    Button {
                        note.speedKmh = last.speedKmh
                        note.inclinePercent = last.inclinePercent
                    } label: {
                        Label("Same as last time: \(WorkoutNoteRecord(healthWorkoutID: note.healthWorkoutID, speedKmh: last.speedKmh, inclinePercent: last.inclinePercent).settingsText ?? "")",
                              systemImage: "arrow.uturn.backward")
                    }
                    .foregroundStyle(Color.accentAmber)
                    .formRow()
                }
            } footer: {
                Text("The Watch doesn't know a treadmill's speed or incline. With them, Walks compares heart rate between walks done the same way, with and without the inhaler. For noticing patterns to talk over with your doctor, not for deciding medication.")
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: note) { _, note in onChange(note) }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value).foregroundStyle(Color.textSecondary)
        }
        .formRow()
    }

    private func numberRow(_ title: String, unit: String, value: Binding<Double?>) -> some View {
        HStack(spacing: Metrics.spaceInner) {
            Text(title).foregroundStyle(Color.textPrimary)
            Spacer()
            TextField("—", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Font.metricNumber)
                .foregroundStyle(Color.accentAmber)
            Text(unit).foregroundStyle(Color.textSecondary)
        }
        .formRow()
    }

    static func distance(_ meters: Double) -> String {
        TreadmillSpeed.usesMiles
            ? "\((meters / 1_609.344).formatted(.number.precision(.fractionLength(2)))) mi"
            : "\((meters / 1_000).formatted(.number.precision(.fractionLength(2)))) km"
    }
}

/// The note sheet, from the Day page or Walks.
final class WorkoutNoteViewController: UIHostingController<WorkoutNoteForm> {

    private static let logger = Logger(category: "Train")

    init(store: Store, workout: HealthWorkout, onChange: @escaping () -> Void) {
        let note = ((try? store.workoutNotes(for: [workout.id])) ?? [:])[workout.id] ?? WorkoutNoteRecord(healthWorkoutID: workout.id)
        let last = try? store.latestTreadmillSettings()
        super.init(rootView: WorkoutNoteForm(workout: workout, note: note, last: nil) { _ in })
        rootView = WorkoutNoteForm(workout: workout, note: note, last: last) { note in
            do {
                try store.setWorkoutNote(note)
                onChange()
            } catch {
                Self.logger.error("Failed to save a workout note: \(error, privacy: .public)")
            }
        }
        title = workout.name
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }
}

/// Average heart rate on each indoor walk over time (DESIGN.md §8 "Trend over time"): a point
/// a walk, lavender with the inhaler and teal without, so the two can be told apart.
struct WalkHeartRateChart: View {

    struct Point: Hashable, Identifiable {
        let date: Date
        let heartRate: Double
        let inhaler: Bool
        var id: Date { date }
    }

    let points: [Point]

    var body: some View {
        Chart(points) { point in
            PointMark(x: .value("Day", point.date), y: .value("Heart rate", point.heartRate))
                .foregroundStyle(point.inhaler ? Color.accentLavender : Color.accentTeal)
                .symbolSize(28)
        }
        .trendChartChrome(over: points.map { TrendPoint(date: $0.date, value: $0.heartRate) })
        .accessibilityLabel("Average heart rate on indoor walks")
    }
}

/// Walks (`.scratch/walks/issues/01`), from Train: the last six months of indoor walks from the
/// Watch. Heart rate on each, the walks grouped by treadmill speed and incline with the
/// inhaler's difference, then every walk, each opening its note.
final class WalksViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")
    static let days = 182

    private let dependencies: AppDependencies
    private let chart = UIHostingController(rootView: WalkHeartRateChart(points: []))
    private let chartCaption = UILabel()
    private let groupsStack = UIStackView()
    private let listStack = UIStackView()
    private var walks: [(workout: HealthWorkout, note: WorkoutNoteRecord?)] = []
    private var asked = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: "Walks")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        chartCaption.font = UIFont.label
        chartCaption.textColor = UIColor.textSecondary
        chartCaption.numberOfLines = 0
        chartCaption.adjustsFontForContentSizeCategory = true

        let overview = CardView(title: "Heart rate on indoor walks", systemImage: "heart.fill", iconTint: UIColor.accentCoral)
        chart.view.backgroundColor = .clear
        chart.sizingOptions = .intrinsicContentSize
        addChild(chart)
        overview.contentStack.addArrangedSubview(chart.view)
        chart.didMove(toParent: self)
        overview.contentStack.addArrangedSubview(chartCaption)

        groupsStack.axis = .vertical
        groupsStack.spacing = Metrics.spaceCard
        listStack.axis = .vertical
        listStack.spacing = Metrics.spaceTight
        let list = CardView(title: "Every walk", systemImage: "figure.walk", iconTint: UIColor.accentAmber)
        list.contentStack.addArrangedSubview(listStack)

        contentStack.addArrangedSubview(overview)
        contentStack.addArrangedSubview(groupsStack)
        contentStack.addArrangedSubview(list)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    private func load() {
        Task {
            let reader = dependencies.healthWorkouts
            if !asked {
                asked = true
                try? await reader.requestWorkoutAccess()
            }
            let today = Day.today()
            let all = (try? await reader.healthWorkouts(from: today.advanced(by: -Self.days), to: today)) ?? []
            let indoor = all.filter { $0.isWalk && $0.isIndoor }.sorted { $0.start > $1.start }
            let notes = (try? dependencies.store.workoutNotes(for: indoor.map(\.id))) ?? [:]
            walks = indoor.map { ($0, notes[$0.id]) }
            render()
        }
    }

    private func render() {
        chart.rootView = WalkHeartRateChart(points: walks.reversed().compactMap { walk in
            walk.workout.averageHeartRate.map { .init(date: walk.workout.start, heartRate: $0, inhaler: walk.note?.usedInhaler ?? false) }
        })
        chartCaption.text = walks.isEmpty
            ? "Indoor walks from your Apple Watch show here. Start an Indoor Walk on the Watch for a treadmill."
            : "A point a walk: lavender with the inhaler, teal without. At the same speed and incline, a lower heart rate means fitter. Tap a walk below to add its treadmill speed, incline, and inhaler."

        groupsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for group in WalkComparison.groups(walks).prefix(3) {
            let card = CardView(title: group.settings, systemImage: "figure.walk.treadmill", iconTint: UIColor.accentAmber)
            func add(_ symbol: String, _ tint: UIColor, _ title: String, _ value: String) {
                let row = MetricRowView()
                row.configure(leading: .symbol(symbol, tint: tint), title: title, value: value)
                card.contentStack.addArrangedSubview(row)
            }
            if let without = group.without {
                add("circle.fill", UIColor.accentTeal, "Without inhaler", "\(Int(without.average.rounded())) bpm · \(without.count) \(without.count == 1 ? "walk" : "walks")")
            }
            if let with = group.withInhaler {
                add("circle.fill", UIColor.accentLavender, "With inhaler", "\(Int(with.average.rounded())) bpm · \(with.count) \(with.count == 1 ? "walk" : "walks")")
            }
            if group.count > 1 {
                add("arrow.right", UIColor.textTertiary, "First → latest", "\(Int(group.first.rounded())) → \(Int(group.latest.rounded())) bpm")
            }
            groupsStack.addArrangedSubview(card)
        }

        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for walk in walks.prefix(40) {
            let row = WeighInLikeRow()
            let settings = walk.note?.settingsText ?? "Add speed and incline"
            let heart = walk.workout.averageHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "—"
            row.configure(title: walk.workout.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                          detail: "\(HealthText.duration(walk.workout.duration)) · \(settings)\(walk.note?.usedInhaler == true ? " · inhaler" : "")",
                          value: heart, highlighted: walk.note?.usedInhaler == true)
            row.addAction(UIAction { [weak self] _ in self?.open(walk.workout) }, for: .touchUpInside)
            listStack.addArrangedSubview(row)
        }
    }

    private func open(_ workout: HealthWorkout) {
        let sheet = WorkoutNoteViewController(store: dependencies.store, workout: workout) { [weak self] in self?.load() }
        present(sheet.inSheet(detents: [.large()]), animated: true)
    }
}

/// A tappable two-line row: title over a detail, a value on the right.
final class WeighInLikeRow: UIControl {

    private let title = UILabel()
    private let detail = UILabel()
    private let value = UILabel()

    init() {
        super.init(frame: .zero)
        title.font = UIFont.bodyText
        title.textColor = UIColor.textPrimary
        detail.font = UIFont.label
        detail.textColor = UIColor.textSecondary
        detail.numberOfLines = 2
        value.font = UIFont.cardTitleMonospaced
        value.textColor = UIColor.textPrimary
        value.setContentHuggingPriority(.required, for: .horizontal)
        for label in [title, detail, value] { label.adjustsFontForContentSizeCategory = true }
        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 1
        let row = UIStackView(arrangedSubviews: [text, value])
        row.alignment = .center
        row.spacing = Metrics.spaceTight
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, detail: String, value: String, highlighted: Bool) {
        self.title.text = title
        self.detail.text = detail
        self.value.text = value
        self.value.textColor = highlighted ? UIColor.accentLavender : UIColor.textPrimary
        accessibilityLabel = "\(title), \(detail), \(value)"
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.5 : 1 }
    }
}
