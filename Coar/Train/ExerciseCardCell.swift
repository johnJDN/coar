import UIKit

/// `ExerciseCard` (DESIGN.md §7) in the live logger: the row's name, "A1 · Barbell · 3 sets",
/// a timer button (starts the rest timer with this row's rest default by hand), a `…` menu
/// (Remove exercise), one `SetRow` per Logged Set, and the footer's split actions,
/// Progression | Add set. Tapping the header opens Progression too. Set rows are kept in
/// place across re-renders so a field being typed in never loses the keyboard; a long-press
/// on a row offers Remove set.
final class ExerciseCardCell: CardCell {

    struct Model: Equatable {
        let name: String
        let subtitle: String
        /// What the timer button starts: the row's rest default, or the 120 s fallback; nil
        /// hides the button (a finished Workout being edited has no rest).
        let restSeconds: Int?
        let sets: [SetRowView.Model]
        /// False when the row's Exercise is gone from the catalogue: there is no page to open.
        let canOpenProgression: Bool
    }

    var onChangeSet: ((LoggedSetRecord.ID, _ weight: String, _ reps: String) -> Void)?
    var onToggleSet: ((LoggedSetRecord.ID, Bool) -> Void)?
    var onRemoveSet: ((LoggedSetRecord.ID) -> Void)?
    var onAddSet: (() -> Void)?
    var onRemoveExercise: (() -> Void)?
    /// The timer button, with the row's rest duration.
    var onStartRest: ((_ seconds: Int) -> Void)?
    /// The header or the Progression footer action.
    var onOpenProgression: (() -> Void)?

    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timerButton = UIButton(configuration: .plain())
    private let moreButton = UIButton(configuration: .plain())
    private let headerText = UIStackView()
    private let headerTap = UITapGestureRecognizer()
    private let progressionButton = UIButton(configuration: .footerAction(title: "Progression", systemImage: "chart.line.uptrend.xyaxis"))
    private let setsStack = UIStackView()
    private var rows: [SetRowView] = []
    private var setIDs: [LoggedSetRecord.ID] = []
    private var restSeconds: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)

        nameLabel.font = UIFont.cardTitle
        nameLabel.textColor = UIColor.textPrimary
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2

        subtitleLabel.font = UIFont.label
        subtitleLabel.textColor = UIColor.textSecondary
        subtitleLabel.adjustsFontForContentSizeCategory = true

        headerText.addArrangedSubview(nameLabel)
        headerText.addArrangedSubview(subtitleLabel)
        headerText.axis = .vertical
        headerText.spacing = 2
        headerTap.addTarget(self, action: #selector(headerTapped))
        headerText.addGestureRecognizer(headerTap)
        nameLabel.accessibilityHint = "Opens progression"

        timerButton.configuration?.image = UIImage(systemName: "timer")
        timerButton.configuration?.baseForegroundColor = UIColor.textSecondary
        timerButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        timerButton.addAction(UIAction { [weak self] _ in
            guard let self, let restSeconds else { return }
            onStartRest?(restSeconds)
        }, for: .touchUpInside)
        timerButton.setContentHuggingPriority(.required, for: .horizontal)

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

        let header = UIStackView(arrangedSubviews: [headerText, timerButton, moreButton])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 0
        header.setCustomSpacing(Metrics.spaceTight, after: headerText)

        setsStack.axis = .vertical
        setsStack.spacing = Metrics.spaceTight

        progressionButton.addAction(UIAction { [weak self] _ in self?.onOpenProgression?() }, for: .touchUpInside)
        let addSet = UIButton(configuration: .footerAction(title: "Add set", systemImage: "plus"), primaryAction: UIAction { [weak self] _ in self?.onAddSet?() })
        let footer = UIStackView(arrangedSubviews: [progressionButton, addSet])
        footer.axis = .horizontal
        footer.distribution = .fillEqually
        footer.spacing = Metrics.spaceTight

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
        restSeconds = model.restSeconds
        timerButton.isHidden = model.restSeconds == nil
        timerButton.accessibilityLabel = model.restSeconds.map { "Start rest timer, \(TrainText.count($0, "second"))" }
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
        progressionButton.isHidden = !model.canOpenProgression
        headerTap.isEnabled = model.canOpenProgression
        nameLabel.accessibilityTraits = model.canOpenProgression ? .button : .staticText
        accessibilityLabel = "\(model.name), \(model.subtitle)"
    }

    @objc private func headerTapped() {
        onOpenProgression?()
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

private extension UIButton.Configuration {
    /// One of the card's footer actions: a small `fill` capsule with a leading symbol.
    static func footerAction(title: String, systemImage: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: systemImage)
        configuration.imagePadding = Metrics.spaceTight
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.buttonSize = .small
        configuration.titleTextAttributesTransformer = .cardTitle
        return configuration
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
