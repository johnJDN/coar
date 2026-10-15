import UIKit
import os

/// The log sheet: one field for a Body Weight in the display unit and the Day it's for
/// (today unless picked; never a future Day). New, it's prefilled with the latest value;
/// opened on a weigh-in, with that one, and it can be deleted. Saving stores kilograms and
/// mirrors to Apple Health through `BodyWeightLogger`; logging on a Day that already has a
/// value replaces it, and moving a weigh-in to another Day removes it from its old one.
final class BodyWeightLogViewController: UIViewController {

    private static let logger = Logger(category: "BodyWeight")

    private let dependencies: AppDependencies
    /// The weigh-in being edited; nil for a new one.
    private let original: BodyWeightRecord?
    private let onLogged: () -> Void
    private let onDeleted: (BodyWeightRecord) -> Void
    private let field = UITextField()
    private let datePicker = UIDatePicker()
    private let saveItem = UIBarButtonItem(systemItem: .save)

    init(dependencies: AppDependencies, day: Day? = nil, onLogged: @escaping () -> Void, onDeleted: @escaping (BodyWeightRecord) -> Void = { _ in }) {
        self.dependencies = dependencies
        self.original = day.flatMap { try? dependencies.store.bodyWeight(on: $0) }
        self.onLogged = onLogged
        self.onDeleted = onDeleted
        super.init(nibName: nil, bundle: nil)
        title = original == nil ? "Log Body Weight" : "Weigh-in"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The sheet the weight screen presents: new with `day` nil, else that Day's weigh-in.
    static func sheet(dependencies: AppDependencies, day: Day? = nil, onLogged: @escaping () -> Void, onDeleted: @escaping (BodyWeightRecord) -> Void = { _ in }) -> UIViewController {
        BodyWeightLogViewController(dependencies: dependencies, day: day, onLogged: onLogged, onDeleted: onDeleted).inSheet(detents: [.medium()])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background

        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        navigationItem.rightBarButtonItem = saveItem

        let unit = dependencies.preferences.massUnit

        field.font = UIFont.heroNumber
        field.textColor = UIColor.textPrimary
        field.textAlignment = .center
        field.keyboardType = .decimalPad
        field.placeholder = "—"
        field.adjustsFontForContentSizeCategory = true
        field.accessibilityLabel = "Body Weight in \(unit.symbol)"
        field.addAction(UIAction { [weak self] _ in self?.updateSaveState() }, for: .editingChanged)
        if let shown = original ?? (try? dependencies.store.bodyWeights().last) {
            field.text = unit.displayValueText(fromKilograms: shown.kilograms)
        }

        let unitLabel = UILabel()
        unitLabel.text = unit.symbol
        unitLabel.font = UIFont.metricNumber
        unitLabel.textColor = UIColor.textSecondary
        unitLabel.adjustsFontForContentSizeCategory = true
        unitLabel.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [field, unitLabel])
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
        view.addSubview(well)

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.maximumDate = Date()
        datePicker.date = (original?.day ?? .today()).start()
        datePicker.tintColor = UIColor.accentTeal
        let dateLabel = UILabel()
        dateLabel.text = "Day"
        dateLabel.font = UIFont.bodyText
        dateLabel.textColor = UIColor.textPrimary
        dateLabel.adjustsFontForContentSizeCategory = true
        let dateRow = UIStackView(arrangedSubviews: [dateLabel, UIView(), datePicker])
        dateRow.alignment = .center
        dateRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dateRow)

        var deleteConfiguration = UIButton.Configuration.plain()
        deleteConfiguration.title = "Delete weigh-in"
        deleteConfiguration.baseForegroundColor = UIColor.accentCoral
        let deleteButton = UIButton(configuration: deleteConfiguration, primaryAction: UIAction { [weak self] _ in self?.delete() })
        deleteButton.isHidden = original == nil
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            dateRow.topAnchor.constraint(equalTo: well.bottomAnchor, constant: Metrics.spaceInner),
            dateRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.spaceEdge + Metrics.spaceInner),
            dateRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.spaceEdge),
            deleteButton.topAnchor.constraint(equalTo: dateRow.bottomAnchor, constant: Metrics.spaceInner),
            deleteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            well.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Metrics.spaceCard),
            well.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            well.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.spaceEdge),

            row.topAnchor.constraint(equalTo: well.topAnchor, constant: Metrics.spaceInner),
            row.leadingAnchor.constraint(equalTo: well.leadingAnchor, constant: Metrics.spaceInner),
            row.trailingAnchor.constraint(equalTo: well.trailingAnchor, constant: -Metrics.spaceInner),
            row.bottomAnchor.constraint(equalTo: well.bottomAnchor, constant: -Metrics.spaceInner),
        ])

        updateSaveState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        field.becomeFirstResponder()
        field.selectAll(nil)
    }

    // MARK: - Saving

    private var enteredValue: Double? {
        guard let text = field.text, let value = Double(typed: text), value > 0 else { return nil }
        return value
    }

    private func updateSaveState() {
        saveItem.isEnabled = enteredValue != nil
    }

    private func save() {
        guard let value = enteredValue else { return }
        saveItem.isEnabled = false
        let logger = BodyWeightLogger(store: dependencies.store, healthWriter: dependencies.bodyWeightWriter)
        let day = Day(datePicker.date)
        Task {
            do {
                if let original, original.day != day {
                    try await logger.delete(on: original.day)
                }
                try await logger.log(value, in: dependencies.preferences.massUnit, on: day)
                onLogged()
                dismiss(animated: true)
            } catch {
                Self.logger.error("Failed to log Body Weight: \(error, privacy: .public)")
                saveItem.isEnabled = true
            }
        }
    }

    /// No confirmation: the weight screen offers Undo.
    private func delete() {
        guard let original else { return }
        let logger = BodyWeightLogger(store: dependencies.store, healthWriter: dependencies.bodyWeightWriter)
        Task {
            do {
                try await logger.delete(on: original.day)
                dismiss(animated: true)
                onDeleted(original)
            } catch {
                Self.logger.error("Failed to delete Body Weight: \(error, privacy: .public)")
            }
        }
    }
}
