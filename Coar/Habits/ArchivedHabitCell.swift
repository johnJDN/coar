import UIKit

/// A row in the Archived section (DESIGN.md §11): emoji, name, Restore, and Delete
/// permanently. Muted, because an archived Habit is out of the way by design.
final class ArchivedHabitCell: UICollectionViewCell {

    var onRestore: (() -> Void)?
    var onDelete: (() -> Void)?

    private let card = CardView()
    private let emojiLabel = UILabel()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

        emojiLabel.font = UIFont.preferredFont(forTextStyle: .title3)
        emojiLabel.adjustsFontForContentSizeCategory = true
        emojiLabel.alpha = 0.6
        emojiLabel.setContentHuggingPriority(.required, for: .horizontal)

        nameLabel.font = UIFont.bodyText
        nameLabel.textColor = UIColor.textSecondary
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2

        var restoreConfig = UIButton.Configuration.filled()
        restoreConfig.title = "Restore"
        restoreConfig.cornerStyle = .capsule
        restoreConfig.baseBackgroundColor = UIColor.fill
        restoreConfig.baseForegroundColor = UIColor.textPrimary
        restoreConfig.buttonSize = .small
        let restore = UIButton(configuration: restoreConfig, primaryAction: UIAction { [weak self] _ in self?.onRestore?() })
        restore.setContentHuggingPriority(.required, for: .horizontal)

        var deleteConfig = UIButton.Configuration.filled()
        deleteConfig.image = UIImage(systemName: "trash")
        deleteConfig.cornerStyle = .capsule
        deleteConfig.baseBackgroundColor = UIColor.fill
        deleteConfig.baseForegroundColor = UIColor.accentCoral
        deleteConfig.buttonSize = .small
        let delete = UIButton(configuration: deleteConfig, primaryAction: UIAction { [weak self] _ in self?.onDelete?() })
        delete.accessibilityLabel = "Delete permanently"
        delete.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [emojiLabel, nameLabel, restore, delete])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = Metrics.spaceTight
        card.contentStack.addArrangedSubview(row)
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(with habit: HabitRecord) {
        emojiLabel.text = habit.emoji
        nameLabel.text = habit.name
        accessibilityLabel = "\(habit.name), archived"
    }
}

/// A section header in the §5 section-header style, with `spaceSection` above.
final class SectionHeaderView: UICollectionReusableView {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = UIFont.sectionHeader
        label.textColor = UIColor.textPrimary
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.spaceSection - Metrics.spaceCard),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Metrics.spaceTight),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var title: String? {
        get { label.text }
        set { label.text = newValue }
    }
}
