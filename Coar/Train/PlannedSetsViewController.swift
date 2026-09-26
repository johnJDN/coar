import UIKit

/// A Plan row's Planned Sets, pushed from the Plan editor: one `SetRow`-style line per set
/// (set number, weight in the display unit, rep range), swipe to delete, an Add set row that
/// repeats the last set. Save hands the row back to the editor's draft (nothing is written
/// until the Plan is saved). A rep range typed as one number is min = max (CONTEXT.md
/// "Planned Set"); the weight is stored in kilograms (ADR 0004).
final class PlannedSetsViewController: UIViewController {

    private enum Item: Hashable {
        case set(PlannedSetFields.ID)
        case add
    }

    private let unit: MassUnit
    private var row: PlanExerciseDraft
    private let onSave: (PlanExerciseDraft) -> Void
    private var fields: [PlannedSetFields]
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Item>!
    private let saveItem = UIBarButtonItem(systemItem: .save)

    init(exerciseName: String, row: PlanExerciseDraft, unit: MassUnit, onSave: @escaping (PlanExerciseDraft) -> Void) {
        self.unit = unit
        self.row = row
        self.onSave = onSave
        fields = row.sets.map { PlannedSetFields($0, in: unit) }
        super.init(nibName: nil, bundle: nil)
        title = exerciseName
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        navigationItem.rightBarButtonItem = saveItem
        configureCollectionView()
        render()
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.showsSeparators = false
        configuration.backgroundColor = .clear
        configuration.headerMode = .supplementary
        configuration.footerMode = .supplementary
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard case .set(let id) = self?.dataSource.itemIdentifier(for: indexPath) else { return nil }
            return UISwipeActionsConfiguration(actions: [
                UIContextualAction(style: .destructive, title: "Delete") { _, _, done in
                    self?.fields.removeAll { $0.id == id }
                    self?.render()
                    done(true)
                },
            ])
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: configuration))
        collectionView.backgroundColor = .clear
        collectionView.dismissesKeyboardOnDrag()
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])

        let setCell = UICollectionView.CellRegistration<PlannedSetCell, PlannedSetFields.ID> { [weak self] cell, indexPath, id in
            guard let self, let set = fields.first(where: { $0.id == id }) else { return }
            cell.configure(number: indexPath.item + 1, fields: set, unitSymbol: unit.symbol)
            cell.onChange = { [weak self] changed in
                guard let self, let index = fields.firstIndex(where: { $0.id == changed.id }) else { return }
                fields[index] = changed
                updateSaveState()
            }
        }
        let addCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            let content = UIListContentConfiguration.addRow("Add set")
            cell.contentConfiguration = content
            cell.accessories = []
            cell.backgroundConfiguration = UIBackgroundConfiguration.listRow()
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionHeader) { view, _, _ in
            var content = UIListContentConfiguration.groupedHeader()
            content.text = "Sets"
            view.contentConfiguration = content
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(elementKind: UICollectionView.elementKindSectionFooter) { [weak self] view, _, _ in
            var content = UIListContentConfiguration.groupedFooter()
            content.text = "Weight in \(self?.unit.symbol ?? ""); leave it empty when no weight is lifted. Reps as one number or a range."
            view.contentConfiguration = content
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .set(let id):
                return collectionView.dequeueConfiguredReusableCell(using: setCell, for: indexPath, item: id)
            case .add:
                return collectionView.dequeueConfiguredReusableCell(using: addCell, for: indexPath, item: item)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            kind == UICollectionView.elementKindSectionHeader
                ? collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
                : collectionView.dequeueConfiguredReusableSupplementary(using: footer, for: indexPath)
        }
    }

    // MARK: - Rendering

    private func render() {
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems(fields.map { .set($0.id) } + [.add], toSection: 0)
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)
        updateSaveState()
    }

    private var sets: [PlannedSetDraft]? {
        let sets = fields.compactMap { $0.set(in: unit) }
        return sets.count == fields.count ? sets : nil
    }

    private func updateSaveState() {
        saveItem.isEnabled = sets != nil
    }

    // MARK: - Actions

    private func addSet() {
        view.endEditing(true)
        let last = fields.last
        fields.append(PlannedSetFields(weight: last?.weight ?? "", repMin: last?.repMin ?? "8", repMax: last?.repMax ?? "12"))
        render()
    }

    private func save() {
        guard let sets else { return }
        row.sets = sets
        onSave(row)
        navigationController?.popViewController(animated: true)
    }
}

extension PlannedSetsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if case .add = dataSource.itemIdentifier(for: indexPath) { addSet() }
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath) == .add
    }
}

/// One Planned Set as typed on its row, before validation.
struct PlannedSetFields: Hashable, Identifiable {
    let id: UUID
    var weight: String
    var repMin: String
    var repMax: String

    init(id: UUID = UUID(), weight: String, repMin: String, repMax: String) {
        self.id = id
        self.weight = weight
        self.repMin = repMin
        self.repMax = repMax
    }

    init(_ set: PlannedSetDraft, in unit: MassUnit) {
        self.init(
            id: set.id,
            weight: set.targetKilograms > 0 ? TrainText.weightValue(set.targetKilograms, in: unit) : "",
            repMin: "\(set.reps.min)",
            repMax: set.reps.min == set.reps.max ? "" : "\(set.reps.max)"
        )
    }

    /// The set as it will be saved, or nil while the reps are missing, the max is below the
    /// min, or a number does not parse. An empty weight is no weight; an empty max is
    /// min = max.
    func set(in unit: MassUnit) -> PlannedSetDraft? {
        guard let min = Int(repMin.trimmingCharacters(in: .whitespaces)), min > 0 else { return nil }
        let maxText = repMax.trimmingCharacters(in: .whitespaces)
        guard let max = maxText.isEmpty ? min : Int(maxText), max >= min else { return nil }
        let weightText = weight.trimmingCharacters(in: .whitespaces)
        let kilograms: Double
        if weightText.isEmpty {
            kilograms = 0
        } else {
            guard let typed = Double(typed: weightText), typed >= 0 else { return nil }
            kilograms = unit.kilograms(fromDisplayValue: typed)
        }
        return PlannedSetDraft(id: id, targetKilograms: kilograms, reps: RepRange(min: min, max: max))
    }
}

/// `SetRow` (DESIGN.md §7) for a Planned Set: `[set #] [weight unit] [min – max]`, three
/// pills in `fill`. Reports every keystroke as new `Fields`.
final class PlannedSetCell: UICollectionViewListCell {

    var onChange: ((PlannedSetFields) -> Void)?

    private var fields: PlannedSetFields?
    private let numberLabel = UILabel()
    private let weightField = UITextField()
    private let unitLabel = UILabel()
    private let minField = UITextField()
    private let maxField = UITextField()

    override init(frame: CGRect) {
        super.init(frame: frame)

        numberLabel.font = UIFont.metricNumber
        numberLabel.textColor = UIColor.textSecondary
        numberLabel.textAlignment = .center
        numberLabel.adjustsFontForContentSizeCategory = true

        for field in [weightField, minField, maxField] {
            field.font = UIFont.metricNumber
            field.textColor = UIColor.textPrimary
            field.textAlignment = .center
            field.placeholder = "—"
            field.adjustsFontForContentSizeCategory = true
            field.addAction(UIAction { [weak self] _ in self?.changed() }, for: .editingChanged)
        }
        weightField.keyboardType = .decimalPad
        weightField.accessibilityLabel = "Weight"
        minField.keyboardType = .numberPad
        minField.accessibilityLabel = "Reps from"
        maxField.keyboardType = .numberPad
        maxField.accessibilityLabel = "Reps to"

        unitLabel.font = UIFont.label
        unitLabel.textColor = UIColor.textSecondary
        unitLabel.adjustsFontForContentSizeCategory = true
        unitLabel.setContentHuggingPriority(.required, for: .horizontal)

        let dash = UILabel()
        dash.text = "–"
        dash.font = UIFont.metricNumber
        dash.textColor = UIColor.textTertiary
        dash.adjustsFontForContentSizeCategory = true
        dash.setContentHuggingPriority(.required, for: .horizontal)

        let numberPill = UIView.pill([numberLabel])
        let weightPill = UIView.pill([weightField, unitLabel])
        let repsPill = UIView.pill([minField, dash, maxField])

        let row = UIStackView(arrangedSubviews: [numberPill, weightPill, repsPill])
        row.axis = .horizontal
        row.spacing = Metrics.spaceTight
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            numberPill.widthAnchor.constraint(equalToConstant: 44),
            weightPill.widthAnchor.constraint(equalTo: repsPill.widthAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Metrics.spaceTight),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Metrics.spaceInner),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Metrics.spaceInner),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Metrics.spaceTight),
        ])
        backgroundConfiguration = UIBackgroundConfiguration.listRow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// A re-render while the user is typing must not move the cursor.
    func configure(number: Int, fields: PlannedSetFields, unitSymbol: String) {
        self.fields = fields
        numberLabel.text = "\(number)"
        unitLabel.text = unitSymbol
        if !weightField.isFirstResponder { weightField.text = fields.weight }
        if !minField.isFirstResponder { minField.text = fields.repMin }
        if !maxField.isFirstResponder { maxField.text = fields.repMax }
        accessibilityLabel = "Set \(number)"
    }

    private func changed() {
        guard var fields else { return }
        fields.weight = weightField.text ?? ""
        fields.repMin = minField.text ?? ""
        fields.repMax = maxField.text ?? ""
        self.fields = fields
        onChange?(fields)
    }
}
