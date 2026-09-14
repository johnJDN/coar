import UIKit
import os

/// The quantitative Habit's number sheet: the Day's total in a hero field with the target
/// beside it, and `+N` chips. A chip adds to the total and writes at once; Done writes the
/// typed total. Every path sets the Day's one Check-in (a total of 0 removes it), so the
/// Day always has exactly one total (CONTEXT.md "Check-in").
final class HabitAmountViewController: UIViewController {

    private static let logger = Logger(category: "Habits")

    private let dependencies: AppDependencies
    private let habitID: HabitRecord.ID
    private let day: Day
    private let onChange: () -> Void
    private let field = UITextField()
    private let targetLabel = UILabel()
    private let chips = UIStackView()
    /// The total on disk, so Done can skip an unchanged write.
    private var savedAmount: Double = 0

    init(dependencies: AppDependencies, habitID: HabitRecord.ID, day: Day, onChange: @escaping () -> Void) {
        self.dependencies = dependencies
        self.habitID = habitID
        self.day = day
        self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The sheet the Habits tab and the detail present.
    static func sheet(dependencies: AppDependencies, habitID: HabitRecord.ID, day: Day, onChange: @escaping () -> Void) -> UIViewController {
        HabitAmountViewController(dependencies: dependencies, habitID: habitID, day: day, onChange: onChange).inSheet(detents: [.medium()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.done() })
        navigationItem.subtitle = day == .today() ? "Today" : day.start().formatted(.dateTime.weekday(.wide).month(.wide).day())

        field.font = UIFont.heroNumber
        field.textColor = UIColor.textPrimary
        field.textAlignment = .center
        field.keyboardType = .decimalPad
        field.placeholder = "0"
        field.adjustsFontForContentSizeCategory = true

        targetLabel.font = UIFont.metricNumber
        targetLabel.textColor = UIColor.textSecondary
        targetLabel.adjustsFontForContentSizeCategory = true
        targetLabel.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [field, targetLabel])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false

        let well = UIView()
        well.backgroundColor = UIColor.surfaceSunken
        well.layer.cornerRadius = Metrics.radiusInner
        well.layer.cornerCurve = .continuous
        well.translatesAutoresizingMaskIntoConstraints = false
        well.addSubview(row)

        chips.axis = .horizontal
        chips.spacing = Metrics.spaceTight
        chips.distribution = .fillEqually
        chips.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(well)
        view.addSubview(chips)
        NSLayoutConstraint.activate([
            well.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Metrics.spaceCard),
            well.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            well.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.spaceEdge),

            row.topAnchor.constraint(equalTo: well.topAnchor, constant: Metrics.spaceInner),
            row.leadingAnchor.constraint(equalTo: well.leadingAnchor, constant: Metrics.spaceInner),
            row.trailingAnchor.constraint(equalTo: well.trailingAnchor, constant: -Metrics.spaceInner),
            row.bottomAnchor.constraint(equalTo: well.bottomAnchor, constant: -Metrics.spaceInner),

            chips.topAnchor.constraint(equalTo: well.bottomAnchor, constant: Metrics.spaceCard),
            chips.leadingAnchor.constraint(equalTo: well.leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: well.trailingAnchor),
        ])

        load()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        field.becomeFirstResponder()
        field.selectAll(nil)
    }

    // MARK: - Reading

    private func load() {
        do {
            guard let habit = try dependencies.store.habit(habitID) else { return dismiss(animated: true) }
            title = "\(habit.emoji) \(habit.name)"
            let target = habit.target(inForceOn: day)
            targetLabel.text = target.map { "of \(HabitAmount.text($0.amount))" }
            targetLabel.isHidden = target == nil
            field.accessibilityLabel = "\(habit.name) total" + (target.map { ", target \(HabitAmount.text($0.amount))" } ?? "")
            savedAmount = try dependencies.store.checkIn(habitID, on: day)?.amount ?? 0
            field.text = savedAmount > 0 ? HabitAmount.text(savedAmount) : nil
            chips.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for step in HabitAmount.quickAdds(target: target?.amount) {
                chips.addArrangedSubview(makeChip(step))
            }
        } catch {
            Self.logger.error("Failed to read Habit: \(error, privacy: .public)")
        }
    }

    private func makeChip(_ step: Double) -> UIButton {
        var configuration = UIButton.Configuration.glass()
        configuration.cornerStyle = .capsule
        configuration.title = "+\(HabitAmount.text(step))"
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.cardTitle
            return attributes
        }
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.add(step) })
        button.accessibilityLabel = "Add \(HabitAmount.text(step))"
        return button
    }

    // MARK: - Writing

    private var enteredAmount: Double? {
        guard let text = field.text, !text.isEmpty else { return 0 }
        guard let value = Self.parser.number(from: text)?.doubleValue ?? Double(text), value >= 0, value.isFinite else { return nil }
        return value
    }

    private static let parser: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        return formatter
    }()

    /// A chip: the typed total plus the step, written at once so "10 more pages" is one tap.
    private func add(_ step: Double) {
        let total = (enteredAmount ?? savedAmount) + step
        write(total)
        UIView.transition(with: field, duration: 0.25, options: .transitionCrossDissolve) {
            self.field.text = HabitAmount.text(total)
        }
    }

    private func done() {
        if let amount = enteredAmount, amount != savedAmount { write(amount) }
        dismiss(animated: true)
    }

    private func write(_ amount: Double) {
        do {
            if amount > 0 {
                try dependencies.store.checkIn(habitID, on: day, amount: amount)
            } else {
                try dependencies.store.removeCheckIn(habitID, on: day)
            }
            savedAmount = amount
            onChange()
        } catch {
            Self.logger.error("Failed to write Check-in: \(error, privacy: .public)")
        }
    }
}
