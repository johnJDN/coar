import UIKit

/// `ExerciseCard` (DESIGN.md §7) in the live logger: the row's name, "A1 · Barbell · 3 sets",
/// a `…` menu (Remove exercise), one `SetRow` per Logged Set, and an Add set footer. The
/// timer button and the Progression footer arrive with tickets 10 and 11. Set rows are kept
/// in place across re-renders so a field being typed in never loses the keyboard; a
/// long-press on a row offers Remove set.
final class ExerciseCardCell: CardCell {

    struct Model: Equatable {
        let name: String
        let subtitle: String
        let sets: [SetRowView.Model]
    }

    var onChangeSet: ((LoggedSetRecord.ID, _ weight: String, _ reps: String) -> Void)?
    var onToggleSet: ((LoggedSetRecord.ID, Bool) -> Void)?
    var onRemoveSet: ((LoggedSetRecord.ID) -> Void)?
    var onAddSet: (() -> Void)?
    var onRemoveExercise: (() -> Void)?

    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let moreButton = UIButton(configuration: .plain())
    private let setsStack = UIStackView()
    private var rows: [SetRowView] = []
    private var setIDs: [LoggedSetRecord.ID] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        nameLabel.font = UIFont.cardTitle
        nameLabel.textColor = UIColor.textPrimary
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2

        subtitleLabel.font = UIFont.label
        subtitleLabel.textColor = UIColor.textSecondary
        subtitleLabel.adjustsFontForContentSizeCategory = true

        let text = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        text.axis = .vertical
        text.spacing = 2

        moreButton.configuration?.image = UIImage(systemName: "ellipsis")
        moreButton.configuration?.baseForegroundColor = UIColor.textSecondary
        moreButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0)
        moreButton.showsMenuAsPrimaryAction = true
        moreButton.menu = UIMenu(children: [
            UIAction(title: "Remove exercise", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.onRemoveExercise?()
            },
        ])
        moreButton.accessibilityLabel = "More"
        moreButton.setContentHuggingPriority(.required, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [text, moreButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = Metrics.spaceTight

        setsStack.axis = .vertical
        setsStack.spacing = Metrics.spaceTight

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Add set"
        configuration.image = UIImage(systemName: "plus")
        configuration.imagePadding = Metrics.spaceTight
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.buttonSize = .small
        configuration.titleTextAttributesTransformer = .cardTitle
        let addSet = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.onAddSet?() })
        let footer = UIStackView(arrangedSubviews: [addSet])
        footer.alignment = .leading

        card.contentStack.addArrangedSubview(header)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: header)
        card.contentStack.addArrangedSubview(setsStack)
        card.contentStack.setCustomSpacing(Metrics.spaceInner, after: setsStack)
        card.contentStack.addArrangedSubview(footer)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rows.forEach { $0.reset() }
    }

    func configure(with model: Model) {
        nameLabel.text = model.name
        subtitleLabel.text = model.subtitle
        setIDs = model.sets.map(\.id)
        while rows.count > model.sets.count {
            let row = rows.removeLast()
            setsStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        while rows.count < model.sets.count {
            rows.append(makeRow(at: rows.count))
        }
        for (row, set) in zip(rows, model.sets) {
            row.configure(set)
        }
        setsStack.isHidden = model.sets.isEmpty
        accessibilityLabel = "\(model.name), \(model.subtitle)"
    }

    private func makeRow(at index: Int) -> SetRowView {
        let row = SetRowView()
        row.onChange = { [weak self] weight, reps in
            guard let self, index < setIDs.count else { return }
            onChangeSet?(setIDs[index], weight, reps)
        }
        row.onToggleComplete = { [weak self] completed in
            guard let self, index < setIDs.count else { return }
            onToggleSet?(setIDs[index], completed)
        }
        row.addInteraction(UIContextMenuInteraction(delegate: self))
        setsStack.addArrangedSubview(row)
        return row
    }
}

extension ExerciseCardCell: UIContextMenuInteractionDelegate {

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let row = interaction.view as? SetRowView, let index = rows.firstIndex(of: row), index < setIDs.count else { return nil }
        let id = setIDs[index]
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Remove set", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    self?.onRemoveSet?(id)
                },
            ])
        })
    }
}
