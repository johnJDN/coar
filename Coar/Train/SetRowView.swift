import UIKit

/// `SetRow` (DESIGN.md §7): `[set #] [weight unit] [reps] [✓]`, four pills in `fill`. Once
/// complete, every pill floods `accentGreen` at 18 % with the text at 100 %, with the §9
/// spring. Typing reports the raw text through `onChange`; the check reports through
/// `onToggleComplete`; the owner writes and re-renders.
final class SetRowView: UIView {

    struct Model: Equatable {
        let id: LoggedSetRecord.ID
        let number: Int
        /// The weight in the display unit as text; empty when none.
        let weight: String
        /// The reps as text; empty when none yet.
        let reps: String
        /// "8–12" from the Planned Set the row came from, shown while the reps are empty.
        let repsHint: String?
        let unitSymbol: String
        let isCompleted: Bool
    }

    var onChange: ((_ weight: String, _ reps: String) -> Void)?
    var onToggleComplete: ((Bool) -> Void)?

    private(set) var isCompleted = false
    private var hasRendered = false

    private let numberLabel = UILabel()
    private let weightField = UITextField()
    private let unitLabel = UILabel()
    private let repsField = UITextField()
    private let checkButton = UIButton(configuration: .plain())
    private let checkSymbol = UIImageView()
    private var pills: [UIView] = []

    private static let completedFill = UIColor.accentGreen.withAlphaComponent(0.18)

    override init(frame: CGRect) {
        super.init(frame: frame)

        numberLabel.font = UIFont.metricNumber
        numberLabel.textAlignment = .center
        numberLabel.adjustsFontForContentSizeCategory = true

        for field in [weightField, repsField] {
            field.font = UIFont.metricNumber
            field.textAlignment = .center
            field.placeholder = "—"
            field.adjustsFontForContentSizeCategory = true
            field.inputAccessoryView = NumberFieldBehavior.doneBar(for: field)
            field.addAction(UIAction { [weak self] _ in self?.changed() }, for: .editingChanged)
        }
        weightField.keyboardType = .decimalPad
        weightField.accessibilityLabel = "Weight"
        repsField.keyboardType = .numberPad
        repsField.accessibilityLabel = "Reps"

        unitLabel.font = UIFont.label
        unitLabel.adjustsFontForContentSizeCategory = true
        unitLabel.setContentHuggingPriority(.required, for: .horizontal)

        checkSymbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        checkSymbol.contentMode = .center
        checkSymbol.translatesAutoresizingMaskIntoConstraints = false
        checkButton.addAction(UIAction { [weak self] _ in self?.tappedCheck() }, for: .touchUpInside)
        checkButton.accessibilityLabel = "Complete set"

        let numberPill = UIView.pill([numberLabel])
        let weightPill = UIView.pill([weightField, unitLabel])
        let repsPill = UIView.pill([repsField])
        let checkPill = UIView.pill([])
        checkPill.addSubview(checkSymbol)
        checkButton.translatesAutoresizingMaskIntoConstraints = false
        checkPill.addSubview(checkButton)
        pills = [numberPill, weightPill, repsPill, checkPill]

        let row = UIStackView(arrangedSubviews: pills)
        row.axis = .horizontal
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            numberPill.widthAnchor.constraint(equalToConstant: 44),
            checkPill.widthAnchor.constraint(equalToConstant: 52),
            weightPill.widthAnchor.constraint(equalTo: repsPill.widthAnchor, multiplier: 1.4),
            checkSymbol.centerXAnchor.constraint(equalTo: checkPill.centerXAnchor),
            checkSymbol.centerYAnchor.constraint(equalTo: checkPill.centerYAnchor),
            checkButton.topAnchor.constraint(equalTo: checkPill.topAnchor),
            checkButton.leadingAnchor.constraint(equalTo: checkPill.leadingAnchor),
            checkButton.trailingAnchor.constraint(equalTo: checkPill.trailingAnchor),
            checkButton.bottomAnchor.constraint(equalTo: checkPill.bottomAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        render(animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// A re-render while the user is typing must not move the cursor.
    func configure(_ model: Model) {
        numberLabel.text = "\(model.number)"
        unitLabel.text = model.unitSymbol
        if !weightField.isFirstResponder { weightField.text = model.weight }
        if !repsField.isFirstResponder { repsField.text = model.reps }
        repsField.placeholder = model.repsHint ?? "—"
        accessibilityLabel = "Set \(model.number)"
        setCompleted(model.isCompleted, animated: true)
    }

    /// Forgets that anything was shown, so a recycled row never springs from another set.
    func reset() {
        hasRendered = false
    }

    private func setCompleted(_ completed: Bool, animated: Bool) {
        let changed = completed != isCompleted
        isCompleted = completed
        let spring = animated && changed && hasRendered && window != nil
        hasRendered = true
        guard spring else { return render(animated: false) }
        for pill in pills { pill.transform = CGAffineTransform(scaleX: 0.94, y: 0.94) }
        UIView.animate(springDuration: 0.4, bounce: 0.15) {
            self.render(animated: true)
            for pill in self.pills { pill.transform = .identity }
        }
    }

    private func render(animated: Bool) {
        let fill = isCompleted ? Self.completedFill : UIColor.fill
        let text = isCompleted ? UIColor.accentGreen : UIColor.textPrimary
        let secondary = isCompleted ? UIColor.accentGreen : UIColor.textSecondary
        for pill in pills { pill.backgroundColor = fill }
        numberLabel.textColor = secondary
        weightField.textColor = text
        repsField.textColor = text
        unitLabel.textColor = secondary
        checkSymbol.image = UIImage(systemName: isCompleted ? "checkmark" : "minus")
        checkSymbol.tintColor = isCompleted ? UIColor.accentGreen : UIColor.textSecondary
        checkButton.accessibilityValue = isCompleted ? "Completed" : "Not completed"
    }

    /// Focus stays where it is: a field being typed in keeps its keyboard (no auto-advance).
    private func tappedCheck() {
        setCompleted(!isCompleted, animated: true)
        onToggleComplete?(isCompleted)
    }

    private func changed() {
        onChange?(weightField.text ?? "", repsField.text ?? "")
    }

    /// The number pads have no return key; a Done bar closes them.
}
