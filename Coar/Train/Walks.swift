import Charts
import SwiftUI
import UIKit
import os

/// Indoor walks made comparable (`.scratch/walks/issues/01`; a pure rule). A walk's effort is
/// the oxygen it takes by the ACSM walking equation (American College of Sports Medicine:
/// 0.1 × speed + 1.8 × speed × grade + 3.5 mL/kg/min, speed in metres a minute), from the
/// treadmill's distance over the Watch's duration and the average incline. Heart rate rises
/// in a straight line with oxygen from the resting rate, so each walk's heart rate is moved
/// to one reference effort (the walks' usual speed and incline): lower there means fitter.
enum WalkEffort {

    struct Reference: Equatable {
        let metersPerMinute: Double
        let inclinePercent: Double

        /// "3.0 mph · 5%".
        var text: String { "\(TreadmillUnits.speedText(metersPerMinute: metersPerMinute)) · \(TreadmillUnits.inclineText(inclinePercent))" }
        var oxygen: Double { WalkEffort.oxygen(metersPerMinute: metersPerMinute, inclinePercent: inclinePercent) }
    }

    struct Scored: Equatable {
        let id: UUID
        let date: Date
        let inhaler: Bool
        let heartRate: Double
        /// The heart rate this walk's fitness would give at the reference effort.
        let atReference: Double
    }

    struct Average: Equatable {
        let heartRate: Double
        let walks: Int
    }

    struct Summary: Equatable {
        let reference: Reference
        /// Oldest first.
        let scored: [Scored]
        /// Over the last `recentDays`, so fitness changing over months doesn't decide it.
        let withInhaler: Average?
        let without: Average?
        /// The first few scored walks against the latest few; nil with fewer than four.
        let earlier: Average?
        let later: Average?
    }

    static let restingFallback = 65.0
    static let recentDays = 56

    /// mL/kg/min by the ACSM walking equation.
    static func oxygen(metersPerMinute: Double, inclinePercent: Double) -> Double {
        0.1 * metersPerMinute + 1.8 * metersPerMinute * inclinePercent / 100 + 3.5
    }

    /// The treadmill's distance over the Watch's duration.
    static func metersPerMinute(_ workout: HealthWorkout, _ note: WorkoutNoteRecord?) -> Double? {
        guard let meters = note?.treadmillMeters, meters > 0, workout.duration > 0 else { return nil }
        return meters / (workout.duration / 60)
    }

    /// A heart rate at one effort moved to another along the straight line from resting.
    static func heartRate(_ heartRate: Double, atOxygen oxygen: Double, movedTo target: Double, resting: Double) -> Double? {
        guard oxygen > 3.5, heartRate > resting else { return nil }
        return resting + (heartRate - resting) * (target - 3.5) / (oxygen - 3.5)
    }

    /// The walks' middle speed (to half a mph or km/h) and incline (to a whole percent).
    static func reference(speeds: [Double], inclines: [Double]) -> Reference {
        func median(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            guard !sorted.isEmpty else { return 0 }
            return sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        }
        let speed = max(0.5, (TreadmillUnits.displaySpeed(metersPerMinute: median(speeds)) * 2).rounded() / 2)
        return Reference(metersPerMinute: TreadmillUnits.metersPerMinute(fromDisplaySpeed: speed), inclinePercent: median(inclines).rounded())
    }

    static func summary(_ walks: [(workout: HealthWorkout, note: WorkoutNoteRecord?)], restingHeartRate: Double?, now: Date = Date()) -> Summary? {
        let usable = walks.compactMap { walk -> (workout: HealthWorkout, inhaler: Bool, speed: Double, incline: Double, heart: Double)? in
            guard let heart = walk.workout.averageHeartRate, let speed = metersPerMinute(walk.workout, walk.note), let incline = walk.note?.inclinePercent else { return nil }
            return (walk.workout, walk.note?.usedInhaler ?? false, speed, incline, heart)
        }
        guard !usable.isEmpty else { return nil }
        let resting = restingHeartRate ?? restingFallback
        let reference = reference(speeds: usable.map(\.speed), inclines: usable.map(\.incline))
        let scored = usable.compactMap { item -> Scored? in
            let oxygen = oxygen(metersPerMinute: item.speed, inclinePercent: item.incline)
            guard let moved = heartRate(item.heart, atOxygen: oxygen, movedTo: reference.oxygen, resting: resting) else { return nil }
            return Scored(id: item.workout.id, date: item.workout.start, inhaler: item.inhaler, heartRate: item.heart, atReference: moved)
        }
        .sorted { $0.date < $1.date }

        func average(_ walks: [Scored]) -> Average? {
            walks.isEmpty ? nil : Average(heartRate: walks.map(\.atReference).reduce(0, +) / Double(walks.count), walks: walks.count)
        }
        let recent = scored.filter { $0.date >= now.addingTimeInterval(-Double(recentDays) * 86_400) }
        let ends = scored.count >= 4 ? min(5, scored.count / 2) : 0
        return Summary(reference: reference, scored: scored,
                       withInhaler: average(recent.filter(\.inhaler)), without: average(recent.filter { !$0.inhaler }),
                       earlier: ends > 0 ? average(Array(scored.prefix(ends))) : nil, later: ends > 0 ? average(Array(scored.suffix(ends))) : nil)
    }
}

/// A Watch workout's note (ADR 0001: SwiftUI leaf, values in, closures out): what it was, then
/// the inhaler, and from the treadmill's display its distance and the incline it was mostly
/// at. Saved as it changes.
struct WorkoutNoteForm: View {

    let workout: HealthWorkout
    @State var note: WorkoutNoteRecord
    /// The incline last set on any walk, offered while this one has none.
    var lastIncline: Double?
    let onChange: (WorkoutNoteRecord) -> Void

    var body: some View {
        Form {
            Section {
                row("When", "\(workout.start.formatted(date: .abbreviated, time: .shortened)) · \(HealthText.duration(workout.duration))")
                if let heart = workout.averageHeartRate { row("Average heart rate", "\(Int(heart.rounded())) bpm") }
                if let meters = workout.distanceMeters, meters > 0 { row("Distance (Watch's guess)", TreadmillUnits.distanceText(meters)) }
            }
            Section {
                Toggle("Used inhaler before", isOn: $note.usedInhaler)
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.accentLavender)
                    .formRow()
                if workout.isWalk { treadmillRows }
            } footer: {
                Text(workout.isWalk
                     ? "From the treadmill's display at the end: its distance (the Watch's guess is often off indoors), and roughly the incline you were at most of the time. With them, Walks turns each walk into an effort, so walks at any speed and incline compare. For noticing patterns to talk over with your doctor, not for deciding medication."
                     : "A record for you and your doctor, not for deciding medication.")
            }
        }
        .font(Font.bodyText)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneBar()
        .background(Color.background)
        .onChange(of: note) { _, note in onChange(note) }
    }

    /// The treadmill's numbers, for a walk only: other workouts have no effort to work out.
    @ViewBuilder private var treadmillRows: some View {
        numberRow("Treadmill distance", unit: TreadmillUnits.distanceUnit, fraction: 0...2, value: Binding(
            get: { note.treadmillMeters.map(TreadmillUnits.displayDistance) },
            set: { note.treadmillMeters = $0.map(TreadmillUnits.meters(fromDisplay:)) }
        ))
        numberRow("Average incline", unit: "%", fraction: 0...1, value: $note.inclinePercent)
        if let lastIncline, note.inclinePercent == nil {
            Button {
                note.inclinePercent = lastIncline
            } label: {
                Label("Same incline as last time: \(TreadmillUnits.inclineText(lastIncline))", systemImage: "arrow.uturn.backward")
            }
            .foregroundStyle(Color.accentAmber)
            .formRow()
        }
        if let speed = WalkEffort.metersPerMinute(workout, note) {
            row("Average speed", TreadmillUnits.speedText(metersPerMinute: speed))
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value).foregroundStyle(Color.textSecondary)
        }
        .formRow()
    }

    private func numberRow(_ title: String, unit: String, fraction: ClosedRange<Int>, value: Binding<Double?>) -> some View {
        HStack(spacing: Metrics.spaceInner) {
            Text(title).foregroundStyle(Color.textPrimary)
            Spacer()
            TextField("—", value: value, format: .number.precision(.fractionLength(fraction)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Font.metricNumber)
                .foregroundStyle(Color.accentAmber)
                .frame(maxWidth: 88)
            Text(unit).foregroundStyle(Color.textSecondary)
        }
        .formRow()
    }
}

/// The note sheet, from the Day page or Walks.
final class WorkoutNoteViewController: UIHostingController<WorkoutNoteForm> {

    private static let logger = Logger(category: "Train")

    init(store: Store, workout: HealthWorkout, onChange: @escaping () -> Void) {
        let note = ((try? store.workoutNotes(for: [workout.id])) ?? [:])[workout.id] ?? WorkoutNoteRecord(healthWorkoutID: workout.id)
        let lastIncline = try? store.latestIncline()
        super.init(rootView: WorkoutNoteForm(workout: workout, note: note, lastIncline: nil) { _ in })
        rootView = WorkoutNoteForm(workout: workout, note: note, lastIncline: lastIncline) { note in
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

/// Heart rate on each indoor walk over time (DESIGN.md §8 "Trend over time"), at the reference
/// effort once walks have their treadmill numbers: a point a walk, lavender with the inhaler
/// and teal without, so the two can be told apart.
struct WalkHeartRateChart: View {

    struct Point: Hashable, Identifiable {
        let date: Date
        let heartRate: Double
        let inhaler: Bool
        var id: Date { date }
    }

    /// Oldest first.
    let points: [Point]

    var body: some View {
        Chart(points) { point in
            PointMark(x: .value("Day", point.date), y: .value("Heart rate", point.heartRate))
                .foregroundStyle(point.inhaler ? Color.accentLavender : Color.accentTeal)
                .symbolSize(28)
        }
        .trendChartChrome(over: points.map { TrendPoint(date: $0.date, value: $0.heartRate) })
        .accessibilityLabel("Heart rate on indoor walks")
    }
}

/// Walks (`.scratch/walks/issues/01`), from Train: the last six months of indoor walks from the
/// Watch. Heart rate on each at one effort once they have their treadmill numbers (as measured
/// before then), the inhaler's difference and the change since the first walks, then every
/// walk, each opening its note.
final class WalksViewController: ScreenViewController {

    static let days = 182

    private let dependencies: AppDependencies
    private let chart = UIHostingController(rootView: WalkHeartRateChart(points: []))
    private let chartSubtitle = UILabel()
    private let chartCaption = UILabel()
    private let summaryStack = UIStackView()
    private let listStack = UIStackView()
    private var walks: [(workout: HealthWorkout, note: WorkoutNoteRecord?)] = []
    private var resting: Double?
    private var asked = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(title: "Walks")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        for (label, color) in [(chartSubtitle, UIColor.textPrimary), (chartCaption, UIColor.textSecondary)] {
            label.font = label === chartSubtitle ? UIFont.bodyText : UIFont.label
            label.textColor = color
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        let overview = CardView(title: "Heart rate on indoor walks", systemImage: "heart.fill", iconTint: UIColor.accentCoral)
        chart.view.backgroundColor = .clear
        chart.sizingOptions = .intrinsicContentSize
        addChild(chart)
        overview.contentStack.addArrangedSubview(chartSubtitle)
        overview.contentStack.addArrangedSubview(chart.view)
        chart.didMove(toParent: self)
        overview.contentStack.addArrangedSubview(chartCaption)

        summaryStack.axis = .vertical
        summaryStack.spacing = Metrics.spaceCard
        listStack.axis = .vertical
        listStack.spacing = Metrics.spaceTight
        let list = CardView(title: "Every walk", systemImage: "figure.walk", iconTint: UIColor.accentAmber)
        list.contentStack.addArrangedSubview(listStack)

        contentStack.addArrangedSubview(overview)
        contentStack.addArrangedSubview(summaryStack)
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
            let first = today.advanced(by: -Self.days)
            let all = (try? await reader.healthWorkouts(from: first, to: today)) ?? []
            let indoor = all.filter { $0.isWalk && $0.isIndoor }.sorted { $0.start > $1.start }
            let notes = (try? dependencies.store.workoutNotes(for: indoor.map(\.id))) ?? [:]
            walks = indoor.map { ($0, notes[$0.id]) }
            if resting == nil {
                // One resting rate for every walk (the period's middle), so they move alike.
                let samples = (try? await dependencies.healthReader.vitalSamples(from: first.start(), to: Date())) ?? []
                let values = samples.filter { $0.vital == .restingHeartRate }.map(\.value).sorted()
                resting = values.isEmpty ? nil : values[values.count / 2]
            }
            render()
        }
    }

    private func render() {
        let summary = WalkEffort.summary(walks, restingHeartRate: resting)
        if let summary {
            chart.rootView = WalkHeartRateChart(points: summary.scored.map { .init(date: $0.date, heartRate: $0.atReference, inhaler: $0.inhaler) })
            chartSubtitle.text = "At \(summary.reference.text), estimated"
            chartSubtitle.isHidden = false
            chartCaption.text = "Each walk's heart rate moved to the same effort from the treadmill's distance and incline, so lower means fitter. Lavender with the inhaler, teal without."
        } else {
            chart.rootView = WalkHeartRateChart(points: walks.reversed().compactMap { walk in
                walk.workout.averageHeartRate.map { .init(date: walk.workout.start, heartRate: $0, inhaler: walk.note?.usedInhaler ?? false) }
            })
            chartSubtitle.isHidden = true
            chartCaption.text = walks.isEmpty
                ? "Indoor walks from your Apple Watch show here. Start an Indoor Walk on the Watch for a treadmill."
                : "Average heart rate as measured. Tap a walk below and add the treadmill's distance and incline: then walks at any speed compare."
        }

        summaryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let summary {
            func card(_ title: String, _ systemImage: String, _ tint: UIColor, rows: [(String, UIColor, String, String)], footnote: String) -> CardView {
                let card = CardView(title: title, systemImage: systemImage, iconTint: tint)
                for (symbol, symbolTint, title, value) in rows {
                    let row = MetricRowView()
                    row.configure(leading: .symbol(symbol, tint: symbolTint), title: title, value: value)
                    card.contentStack.addArrangedSubview(row)
                }
                let note = UILabel()
                note.text = footnote
                note.font = UIFont.label
                note.textColor = UIColor.textTertiary
                note.numberOfLines = 0
                note.adjustsFontForContentSizeCategory = true
                card.contentStack.addArrangedSubview(note)
                return card
            }
            func text(_ average: WalkEffort.Average) -> String {
                "\(Int(average.heartRate.rounded())) bpm · \(average.walks) \(average.walks == 1 ? "walk" : "walks")"
            }
            var inhaler: [(String, UIColor, String, String)] = []
            if let without = summary.without { inhaler.append(("circle.fill", UIColor.accentTeal, "Without", text(without))) }
            if let with = summary.withInhaler { inhaler.append(("circle.fill", UIColor.accentLavender, "With", text(with))) }
            if !inhaler.isEmpty {
                summaryStack.addArrangedSubview(card("Inhaler", "lungs.fill", UIColor.accentLavender, rows: inhaler,
                                                     footnote: "The last \(WalkEffort.recentDays / 7) weeks, at \(summary.reference.text). A few walks each way before reading much into it."))
            }
            if let earlier = summary.earlier, let later = summary.later {
                summaryStack.addArrangedSubview(card("Fitness", "chart.line.downtrend.xyaxis", UIColor.accentGreen, rows: [
                    ("arrow.right", UIColor.textTertiary, "First \(earlier.walks) → latest \(later.walks)", "\(Int(earlier.heartRate.rounded())) → \(Int(later.heartRate.rounded())) bpm"),
                ], footnote: "Heart rate at \(summary.reference.text): lower is fitter."))
            }
        }

        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for walk in walks.prefix(40) {
            let row = WalkRow()
            let settings = walk.note?.settingsText ?? "Add treadmill numbers"
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
final class WalkRow: UIControl {

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
