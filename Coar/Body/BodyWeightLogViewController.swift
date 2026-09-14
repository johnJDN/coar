import UIKit
import os

/// The log sheet: one field for today's Body Weight in the display unit, prefilled with
/// the latest value. Saving stores kilograms for today and mirrors to Apple Health through
/// `BodyWeightLogger`; logging on a Day that already has a value replaces it.
final class BodyWeightLogViewController: UIViewController {

    private static let logger = Logger(category: "BodyWeight")

    private let dependencies: AppDependencies
    private let onLogged: () -> Void
    private let field = UITextField()
    private let saveItem = UIBarButtonItem(systemItem: .save)

    init(dependencies: AppDependencies, onLogged: @escaping () -> Void) {
        self.dependencies = dependencies
        self.onLogged = onLogged
        super.init(nibName: nil, bundle: nil)
        title = "Log Body Weight"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The sheet the weight screen presents.
    static func sheet(dependencies: AppDependencies, onLogged: @escaping () -> Void) -> UIViewController {
        BodyWeightLogViewController(dependencies: dependencies, onLogged: onLogged).inSheet(detents: [.medium()])
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
        if let latest = try? dependencies.store.bodyWeights().last {
            field.text = unit.displayValueText(fromKilograms: latest.kilograms)
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

        NSLayoutConstraint.activate([
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
        guard let text = field.text, let value = Self.parser.number(from: text)?.doubleValue ?? Double(text) else { return nil }
        return value > 0 && value.isFinite ? value : nil
    }

    private static let parser: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        return formatter
    }()

    private func updateSaveState() {
        saveItem.isEnabled = enteredValue != nil
    }

    private func save() {
        guard let value = enteredValue else { return }
        saveItem.isEnabled = false
        let logger = BodyWeightLogger(store: dependencies.store, healthWriter: dependencies.bodyWeightWriter)
        Task {
            do {
                try await logger.log(value, in: dependencies.preferences.massUnit)
                onLogged()
                dismiss(animated: true)
            } catch {
                Self.logger.error("Failed to log Body Weight: \(error, privacy: .public)")
                saveItem.isEnabled = true
            }
        }
    }
}
