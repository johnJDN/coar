import UIKit

/// A Plan on the Train root (DESIGN.md §7 `Card` with a trailing `→`): its name, how many
/// Exercises it has, and their names. Tapping opens the editor.
final class PlanCardControl: UIControl {

    private let card: CardView

    init(plan: PlanRecord) {
        card = CardView(title: plan.name, systemImage: "list.bullet.rectangle.fill", accessory: .navigates)
        super.init(frame: .zero)

        let count = UILabel()
        count.text = TrainText.count(plan.exercises.count, "exercise")
        count.font = UIFont.metricNumber
        count.textColor = UIColor.textPrimary
        count.adjustsFontForContentSizeCategory = true

        let names = UILabel()
        names.text = plan.exercises.isEmpty ? "—" : plan.exercises.map(\.name).joined(separator: " · ")
        names.font = UIFont.label
        names.textColor = plan.exercises.isEmpty ? UIColor.textTertiary : UIColor.textSecondary
        names.adjustsFontForContentSizeCategory = true
        names.numberOfLines = 2

        card.contentStack.addArrangedSubview(count)
        card.contentStack.addArrangedSubview(names)
        card.isUserInteractionEnabled = false
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(plan.name), \(count.text ?? "")"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isHighlighted: Bool {
        didSet { card.alpha = isHighlighted ? 0.85 : 1 }
    }
}

/// A row in the Train root's Archived section: the Plan's name and Restore. Muted, because
/// an archived Plan is out of the way by design.
final class ArchivedPlanView: UIView {

    init(plan: PlanRecord, onRestore: @escaping () -> Void) {
        super.init(frame: .zero)

        let name = UILabel()
        name.text = plan.name
        name.font = UIFont.bodyText
        name.textColor = UIColor.textSecondary
        name.adjustsFontForContentSizeCategory = true
        name.numberOfLines = 2

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Restore"
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.buttonSize = .small
        let restore = UIButton(configuration: configuration, primaryAction: UIAction { _ in onRestore() })
        restore.accessibilityLabel = "Restore \(plan.name)"
        restore.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [name, restore])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight

        let card = CardView()
        card.contentStack.addArrangedSubview(row)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
