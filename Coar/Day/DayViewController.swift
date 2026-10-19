import SwiftUI
import UIKit
import os

/// The Day page (`.scratch/day-page/issues/06`): one Day as it happened, pushed from Home's
/// timeline button; ‹ › move a Day (never past today). Three cards:
/// - the Day's place and weather (with Apple's attribution) and the mood and energy check-in;
/// - the timeline (`DayTimeline`): waking, meals, workouts (Coar's and the Watch's), the
///   weigh-in, journal events, falling asleep; meals and workouts open, sleep opens the Sleep
///   page;
/// - a summary: calories against the Target, habits done, steps, and the Sleep Score.
/// Read on every appearance; Health and weather live, never stored (ADR 0002).
final class DayViewController: ScreenViewController {

    private static let logger = Logger(category: "Day")

    private let dependencies: AppDependencies
    private var day: Day
    private let placeLabel = UILabel()
    private let placeIcon = UIImageView()
    private lazy var weatherButton = UIButton.inCardAction(title: "Show weather", systemImage: "location.fill") { [weak self] in self?.turnOnWeather() }
    private let attribution = UIHostingController(rootView: WeatherAttributionView(attribution: nil))
    private let mood = MoodCardContent()
    private let timelineStack = UIStackView()
    private let timelineEmpty = UILabel()
    private let summaryStack = UIStackView()
    private lazy var previousItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), primaryAction: UIAction { [weak self] _ in self?.move(by: -1) })
    private lazy var nextItem = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), primaryAction: UIAction { [weak self] _ in self?.move(by: 1) })
    private var loadTask: Task<Void, Never>?

    init(dependencies: AppDependencies, day: Day) {
        self.dependencies = dependencies
        self.day = day
        super.init(title: day.title())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        previousItem.accessibilityLabel = "Previous day"
        nextItem.accessibilityLabel = "Next day"
        navigationItem.rightBarButtonItems = [nextItem, previousItem]

        for label in [placeLabel, timelineEmpty] {
            label.font = UIFont.bodyText
            label.textColor = UIColor.textPrimary
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
        }
        timelineEmpty.textColor = UIColor.textTertiary
        timelineEmpty.text = "Nothing recorded for this day yet."
        placeIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        placeIcon.tintColor = UIColor.accentBlue
        placeIcon.setContentHuggingPriority(.required, for: .horizontal)
        let placeRow = UIStackView(arrangedSubviews: [placeIcon, placeLabel])
        placeRow.spacing = Metrics.spaceTight
        placeRow.alignment = .center

        let header = CardView()
        header.contentStack.addArrangedSubview(placeRow)
        header.contentStack.addArrangedSubview(UIStackView(arrangedSubviews: [weatherButton, UIView()]))
        attribution.view.backgroundColor = .clear
        attribution.sizingOptions = .intrinsicContentSize
        addChild(attribution)
        header.contentStack.addArrangedSubview(attribution.view)
        attribution.didMove(toParent: self)
        header.contentStack.setCustomSpacing(Metrics.spaceInner, after: attribution.view)
        header.contentStack.addArrangedSubview(mood)
        mood.onMood = { [weak self] in self?.setMood(mood: $0) }
        mood.onEnergy = { [weak self] in self?.setMood(energy: $0) }

        timelineStack.axis = .vertical
        timelineStack.spacing = Metrics.spaceTight
        let timeline = CardView(title: "Timeline", systemImage: "calendar.day.timeline.left", iconTint: UIColor.textPrimary)
        timeline.contentStack.addArrangedSubview(timelineStack)
        timeline.contentStack.addArrangedSubview(timelineEmpty)

        summaryStack.axis = .vertical
        summaryStack.spacing = Metrics.spaceTight / 2
        let summary = CardView(title: "Summary", systemImage: "list.bullet.rectangle", iconTint: UIColor.textPrimary)
        summary.contentStack.addArrangedSubview(summaryStack)

        contentStack.addArrangedSubview(header)
        contentStack.addArrangedSubview(timeline)
        contentStack.addArrangedSubview(summary)
        render(nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    private func move(by days: Int) {
        let next = day.advanced(by: days)
        guard next <= .today() else { return }
        day = next
        load()
    }

    // MARK: - Reading

    private struct Snapshot {
        var inputs: DayTimeline.Inputs
        var place: PlaceRecord?
        var weather: DayWeatherSummary?
        var attribution: WeatherAttribution?
        var mood: MoodRecord?
        var calories: (eaten: Double, target: Double?)?
        var habits: (done: Int, total: Int)?
        var steps: Int?
        var score: SleepScore?
    }

    private func load() {
        title = day.title()
        nextItem.isEnabled = day < .today()
        loadTask?.cancel()
        let day = self.day
        loadTask = Task { [weak self] in
            guard let self else { return }
            let snapshot = await read(day)
            guard !Task.isCancelled, day == self.day else { return }
            render(snapshot)
        }
    }

    private func read(_ day: Day) async -> Snapshot {
        let store = dependencies.store
        let reader = dependencies.healthReader
        var inputs = DayTimeline.Inputs(day: day)
        inputs.entries = (try? store.entries(on: day)) ?? []
        inputs.workouts = (try? store.workouts(on: day)) ?? []
        inputs.journal = (try? store.journalEvents(on: day)) ?? []
        let unit = dependencies.preferences.massUnit
        inputs.weighedIn = ((try? store.bodyWeight(on: day)) ?? nil).map { unit.displayText(fromKilograms: $0.kilograms) }
        inputs.healthWorkouts = (try? await dependencies.healthWorkouts.healthWorkouts(on: day)) ?? []

        let nightDays = (-HealthDetailViewController.patternNights...1).map { day.advanced(by: $0) }
        let nights = (try? await reader.sleepNights(wakingOn: nightDays)) ?? [:]
        inputs.woke = nights[day]?.woke
        if let next = nights[day.advanced(by: 1)], Day(next.fellAsleep) == day || next.fellAsleep.timeIntervalSince(day.start()) < 30 * 3_600 {
            inputs.fellAsleep = next.fellAsleep
        }
        var snapshot = Snapshot(inputs: inputs)

        if let night = nights[day] {
            let before = nights.filter { $0.key < day }
            let goal = (HealthTarget.current(for: .sleep, store: store, today: day)?.amount ?? 8) * 3_600
            snapshot.score = SleepScore.score(night, wakingOn: day, goal: goal, usualBedtime: SleepPattern.from(before, in: .current)?.bedtime, calendar: .current)
        }
        snapshot.mood = (try? store.mood(on: day)) ?? nil
        snapshot.place = (try? store.place(on: day)) ?? nil
        if let place = snapshot.place {
            snapshot.weather = try? await dependencies.weather.weather(on: day, latitude: place.latitude, longitude: place.longitude)
            if snapshot.weather != nil { snapshot.attribution = await dependencies.weather.attribution() }
        }
        if let eaten = ((try? store.dailyTotals(from: day, to: day)) ?? [:])[day] {
            snapshot.calories = (eaten.calories, ((try? store.target(inForceOn: day)) ?? nil)?.macros.calories)
        }
        let habits = ((try? store.habits()) ?? []).filter { $0.tracking == nil }
        if !habits.isEmpty {
            let done = habits.filter { habit in
                let checkIns = (try? store.checkIns(for: habit.id)) ?? []
                return HabitCardModel(habit: habit, checkIns: checkIns, today: day).isDoneToday
            }
            snapshot.habits = (done.count, habits.count)
        }
        snapshot.steps = try? await reader.steps(on: day)
        return snapshot
    }

    // MARK: - Rendering

    private func render(_ snapshot: Snapshot?) {
        let place = snapshot?.place
        let weather = snapshot?.weather
        placeIcon.image = UIImage(systemName: weather?.symbolName ?? "location")
        if let place, let weather {
            placeLabel.text = "\(place.name.isEmpty ? "Here" : place.name) · \(weather.text)"
        } else if let place {
            placeLabel.text = place.name.isEmpty ? "No weather for this place yet" : place.name
        } else if day == .today(), dependencies.places?.isAllowed == false {
            placeLabel.text = "Weather needs where you are, once a day."
        } else {
            placeLabel.text = "No place recorded for this day"
        }
        placeLabel.textColor = place == nil ? UIColor.textSecondary : UIColor.textPrimary
        weatherButton.superview?.isHidden = !(day == .today() && place == nil && dependencies.places?.isAllowed == false)
        attribution.rootView = WeatherAttributionView(attribution: snapshot?.attribution)
        attribution.view.isHidden = snapshot?.attribution == nil
        mood.render(snapshot?.mood)

        timelineStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let items = snapshot.map { DayTimeline.items($0.inputs) } ?? []
        for item in items {
            let row = DayItemRow(item: item)
            if tapAction(for: item) != nil {
                row.addAction(UIAction { [weak self] _ in self?.tapAction(for: item)?() }, for: .touchUpInside)
            } else {
                row.isEnabled = false
            }
            timelineStack.addArrangedSubview(row)
        }
        timelineEmpty.isHidden = !items.isEmpty || snapshot == nil

        summaryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        func add(_ symbol: String, _ tint: UIColor, _ title: String, _ value: String) {
            let row = MetricRowView()
            row.configure(leading: .symbol(symbol, tint: tint), title: title, value: value)
            summaryStack.addArrangedSubview(row)
        }
        if let calories = snapshot?.calories {
            let eaten = Int(calories.eaten.rounded()).formatted()
            add("flame.fill", UIColor.accentAmber, "Calories", calories.target.map { "\(eaten) of \(Int($0.rounded()).formatted()) cal" } ?? "\(eaten) cal")
        }
        if let habits = snapshot?.habits {
            add("checkmark.circle.fill", UIColor.accentGreen, "Habits", "\(habits.done) of \(habits.total) done")
        }
        if let steps = snapshot?.steps {
            add(HealthMetric.steps.systemImage, UIColor.accentAmber, "Steps", HealthText.steps(steps))
        }
        if let score = snapshot?.score {
            add("moon.stars.fill", UIColor.accentTeal, "Sleep score", "\(score.total) · \(score.label)")
        }
        if summaryStack.arrangedSubviews.isEmpty, snapshot != nil {
            add("minus.circle", UIColor.textTertiary, "Nothing to sum up yet", "")
        }
    }

    private func tapAction(for item: DayItem) -> (() -> Void)? {
        switch item.kind {
        case .meal(let id):
            return { [weak self] in
                guard let self, let sheet = EntryDetailViewController.sheet(dependencies: dependencies, entryID: id, onChange: { [weak self] in self?.load() }) else { return }
                present(sheet, animated: true)
            }
        case .workout(let id):
            return { [weak self] in
                guard let self else { return }
                navigationController?.pushViewController(WorkoutDetailViewController(dependencies: dependencies, workoutID: id), animated: true)
            }
        case .woke, .fellAsleep:
            return { [weak self] in
                guard let self else { return }
                navigationController?.pushViewController(HealthDetailViewController(dependencies: dependencies, metric: .sleep), animated: true)
            }
        case .healthWorkout, .weighIn, .journal:
            return nil
        }
    }

    // MARK: - Actions

    private func setMood(mood: Int? = nil, energy: Int? = nil) {
        do {
            try dependencies.store.setMood(on: day, mood: mood, energy: energy)
        } catch {
            Self.logger.error("Failed to save mood: \(error, privacy: .public)")
        }
        Task { await dependencies.reminder?.refresh() }
        self.mood.render((try? dependencies.store.mood(on: day)) ?? nil)
    }

    private func turnOnWeather() {
        Task {
            await dependencies.places?.requestAccess()
            load()
        }
    }
}

/// The mood and energy check-in without its own card, for the Day page's header.
final class MoodCardContent: UIView {

    var onMood: ((Int) -> Void)?
    var onEnergy: ((Int) -> Void)?
    private var content: (UIView & UIContentView)?

    func render(_ record: MoodRecord?) {
        let configuration = UIHostingConfiguration {
            MoodEnergyView(mood: record?.mood, energy: record?.energy,
                           onMood: { [weak self] in self?.onMood?($0) },
                           onEnergy: { [weak self] in self?.onEnergy?($0) })
        }
        .margins(.all, 0)
        if let content {
            content.configuration = configuration
            return
        }
        let view = configuration.makeContentView()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        content = view
    }
}

/// One timeline row: the time in a fixed column, the thing's icon in its tint, its title and
/// a detail line. Approximate times read "Morning" in `textTertiary`.
final class DayItemRow: UIControl {

    init(item: DayItem) {
        super.init(frame: .zero)
        let time = UILabel()
        time.text = item.timeText
        time.font = UIFont.label
        time.textColor = item.isApproximate ? UIColor.textTertiary : UIColor.textSecondary
        time.adjustsFontForContentSizeCategory = true
        time.widthAnchor.constraint(equalToConstant: 76).isActive = true

        let icon = UIImageView(image: UIImage(systemName: item.systemImage))
        icon.tintColor = item.tint
        icon.contentMode = .center
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let title = UILabel()
        title.text = item.title
        title.font = UIFont.bodyText
        title.textColor = UIColor.textPrimary
        title.numberOfLines = 2
        title.adjustsFontForContentSizeCategory = true
        let detail = UILabel()
        detail.text = item.detail
        detail.font = UIFont.label
        detail.textColor = UIColor.textSecondary
        detail.adjustsFontForContentSizeCategory = true
        detail.isHidden = item.detail == nil
        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 1

        let row = UIStackView(arrangedSubviews: [time, icon, text])
        row.spacing = Metrics.spaceTight
        row.alignment = .firstBaseline
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
        accessibilityLabel = [item.timeText, item.title, item.detail].compactMap { $0 }.joined(separator: ", ")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.5 : 1 }
    }
}

/// Apple's required WeatherKit attribution: the Apple Weather mark for the current
/// appearance, linking to the legal page.
struct WeatherAttributionView: View {
    let attribution: WeatherAttribution?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let attribution {
            Link(destination: attribution.legalPage) {
                AsyncImage(url: colorScheme == .dark ? attribution.markDark : attribution.markLight) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text("Weather").font(Font.label).foregroundStyle(Color.textTertiary)
                }
                .frame(height: 12)
            }
            .accessibilityLabel("Apple Weather, data sources")
        }
    }
}
