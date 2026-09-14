import UIKit

/// A row in the Archived section (DESIGN.md §11): emoji, name, Restore, and Delete
/// permanently. Muted, because an archived Habit is out of the way by design.
final class ArchivedHabitCell: CardCell {

    var onRestore: (() -> Void)?
    var onDelete: (() -> Void)?

    private let emojiLabel = UILabel()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

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
    }

    func configure(with habit: HabitRecord) {
        emojiLabel.text = habit.emoji
        nameLabel.text = habit.name
        accessibilityLabel = "\(habit.name), archived"
    }
}
