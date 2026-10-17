import Network
import PhotosUI
import SwiftUI
import UIKit
import os

/// The Describe tab of the "+" sheet (`.scratch/ai-food-logging/spec.md`): type what was
/// eaten, one food per line; each line is estimated two seconds after its last edit, or at
/// once on Return or leaving it; the sheet's Add logs every filled line as an Entry of its
/// own (CONTEXT.md "Entry") at the sheet's time. Lines still checking or failed stay behind.
/// A missing, rejected, or spent key is one `WarningCard` above the lines, not a per-line
/// error. The draft owns every change; this controller owns the timing and the requests.
/// The draft is kept on this iPhone after every change, so closing the sheet or quitting
/// loses nothing, and lines waiting for a connection go again as soon as there is one.
final class DescribeViewController: UIViewController {

    private static let logger = Logger(category: "Food")
    /// How long a line rests before it is sent.
    private static let settle: Duration = .seconds(2)

    private enum Section: Hashable {
        case problem, lines, total
    }

    private enum Item: Hashable {
        case problem
        case line(DescribeLine.ID)
        /// "Add food" under the last line, while that line has something in it.
        case addRow
        case total
    }

    private let dependencies: AppDependencies
    private let instant: Date
    private let onLogged: () -> Void
    /// Called whenever what Add would do changes, so the sheet can enable it.
    var onChange: () -> Void = {}

    private let draftFile: DescribeDraftFile
    private var draft: DescribeDraft {
        didSet { draftFile.save(draft) }
    }
    private let pathMonitor = NWPathMonitor()
    private var problem: OpenRouterError?
    private var timers: [DescribeLine.ID: Task<Void, Never>] = [:]
    /// Photos being read, by their placeholder line: kept in memory until read, so a failed
    /// one can be tried again, and never written anywhere.
    private var photos: [DescribeLine.ID: [Data]] = [:]
    /// Photos taken or chosen for the next read, before "Anything to add?" sends them.
    private var pendingPhotos: [Data] = []
    /// Up to this many photos are read together (a label wrapping around a package).
    static let maximumPhotos = 3
    /// What the user said about each photo, sent with it (and again on a retry).
    private var photoNotes: [DescribeLine.ID: String] = [:]
    private var collectionView: UICollectionView!
    /// Your foods offered above the keyboard for the line being typed.
    private let suggestionBar = SuggestionBar()
    private var suggestingLine: DescribeLine.ID?
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    init(dependencies: AppDependencies, at instant: Date, draftFile: DescribeDraftFile = .standard, onLogged: @escaping () -> Void) {
        self.dependencies = dependencies
        self.instant = instant
        self.draftFile = draftFile
        self.onLogged = onLogged
        draft = draftFile.load()
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        pathMonitor.cancel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        #if DEBUG
        seedLinesForDebugging()
        #endif
        configureCollectionView()
        suggestionBar.onPick = { [weak self] in self?.pick($0) }
        checkKey()
        render(animated: false)
        draft.unsent.forEach(send)
        watchForConnection()
    }

    /// Sends every waiting line when a network path appears. Nothing retries while there is
    /// none, so no request loop runs offline.
    private func watchForConnection() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.draft.waiting.forEach(self.send)
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.johnnguyen.coar.describe-path"))
    }

    #if DEBUG
    /// `-DescribeLines 2_eggs|toast` starts the tab with those lines typed ("_" for a space,
    /// since some launchers split arguments at spaces), for looking at it in a simulator
    /// that has no keyboard to type with. Never used by tests.
    private func seedLinesForDebugging() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-DescribeLines"), flag + 1 < arguments.count else { return }
        draft = DescribeDraft()
        var previous: DescribeLine.ID?
        for text in arguments[flag + 1].split(separator: "|") {
            let id = previous.map { draft.insertLine(after: $0) } ?? draft.lines[0].id
            draft.edit(id, text: text.replacingOccurrences(of: "_", with: " "))
            previous = id
        }
    }
    #endif

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkKey()
    }

    /// Nothing is typed yet: the tab opens with the keyboard up.
    func focusFirstEmptyLine() {
        guard let line = draft.lines.first(where: { $0.trimmedText.isEmpty }) ?? draft.lines.last else { return }
        focus(line.id)
    }

    // MARK: - Add

    /// How many lines Add would log.
    var filledCount: Int {
        draft.filled.count
    }

    /// Logs every filled line as its own Entry; returns whether anything typed is left behind.
    func addFilled() -> Bool {
        var logged: Set<DescribeLine.ID> = []
        for line in draft.filled {
            guard let estimate = line.estimate else { continue }
            do {
                try dependencies.store.logDescribed(estimate, typed: line.trimmedText, savingAsFood: line.saveAsFood, at: instant)
                logged.insert(line.id)
            } catch {
                Self.logger.error("Failed to log Entry: \(error, privacy: .public)")
            }
        }
        guard !logged.isEmpty else { return true }
        draft.remove(logged)
        onLogged()
        render()
        onChange()
        return draft.lines.contains { !$0.trimmedText.isEmpty }
    }

    /// Nothing typed, so Clear has nothing to do.
    var isEmpty: Bool {
        draft.isEmpty
    }

    /// Drops every line, typed or filled: a draft, so no confirm, and typing it again is cheap.
    func clear() {
        timers.values.forEach { $0.cancel() }
        timers = [:]
        view.endEditing(true)
        draft = DescribeDraft()
        render()
        onChange()
        focusFirstEmptyLine()
    }

    /// One Entry: through the Food Item or Meal it matched, so it links to it (spec "Your
    /// library wins"); on its own otherwise. A match archived or deleted since it was made is
    /// logged on its own with the numbers shown, rather than lost.
    // MARK: - Key

    /// Shows the no-key card while there is no key, and takes it away once there is one,
    /// sending what was held back. A rejected or spent key is cleared only by a visit to
    /// Settings (`openSettings`), since nothing here can tell it was fixed.
    private func checkKey() {
        let before = problem
        if dependencies.openRouter.keys.read() == nil {
            problem = .noKey
        } else if problem == .noKey {
            problem = nil
        }
        guard problem != before else { return }
        render()
        draft.unsent.forEach(send)
    }

    private func openSettings() {
        view.endEditing(true)
        present(SettingsViewController.sheet(dependencies: dependencies) { [weak self] in
            guard let self else { return }
            problem = dependencies.openRouter.keys.read() == nil ? .noKey : nil
            render()
            draft.unsent.forEach(send)
        }, animated: true)
    }

    // MARK: - Estimating

    private func edited(_ id: DescribeLine.ID, text: String) {
        let before = draft.line(id)?.state
        photos[id] = nil
        photoNotes[id] = nil
        guard draft.edit(id, text: text) else { return }
        syncAddRow()
        suggest(for: id, text: text)
        timers[id]?.cancel()
        if draft.line(id)?.state != before {
            reconfigure(id)
            onChange()
        }
        timers[id] = Task { [weak self] in
            try? await Task.sleep(for: Self.settle)
            guard !Task.isCancelled else { return }
            self?.send(id)
        }
    }

    private func send(_ id: DescribeLine.ID) {
        timers[id]?.cancel()
        timers[id] = nil
        if let jpegs = photos[id] {
            sendPhoto(id, jpegs: jpegs)
            return
        }
        guard let line = draft.line(id), !line.isPhoto else { return }
        let text = line.trimmedText
        guard !text.isEmpty else { return }
        let library = currentLibrary()
        if let match = library.exactMatch(text), draft.begin(id) != nil {
            received(id, sentText: text, result: .success(match))
            return
        }
        guard problem == nil, draft.begin(id) != nil else { return }
        reconfigure(id)
        let estimator = dependencies.foodEstimator
        Task { [weak self] in
            let result: Result<Estimate, Error>
            do {
                result = .success(try await estimator.estimate(text, library: library))
            } catch {
                result = .failure(error)
            }
            self?.received(id, sentText: text, result: result)
        }
    }

    // MARK: - Photos

    /// Whether this device can take a photo (the simulator can't).
    static var canTakePhoto: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func takePhoto() {
        view.endEditing(true)
        pendingPhotos = []
        presentCamera()
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    func choosePhoto() {
        view.endEditing(true)
        pendingPhotos = []
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = Self.maximumPhotos
        configuration.selection = .ordered
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// Asks for an optional note before the photos are read ("I ate half", "45 g", "it's
    /// turkey"): what the model can't see, it is told. From the camera, Add another photo takes
    /// the next part of a label that wraps around (up to three, read together). Read with the
    /// field empty sends them as they are.
    private func add(_ images: [UIImage], fromCamera: Bool) {
        pendingPhotos += images.compactMap(FoodPhoto.jpeg)
        guard !pendingPhotos.isEmpty else {
            Self.logger.error("Couldn't encode the photo")
            return
        }
        let count = pendingPhotos.count
        let message = count > 1
            ? "\(count) photos, read together as one label or one meal. How much you ate, or what something is."
            : "How much you ate, or what something is. Leave it empty to just read the photo."
        let alert = UIAlertController(title: "Anything to add?", message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "I ate half"
            field.autocapitalizationType = .sentences
            field.returnKeyType = .done
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.pendingPhotos = [] })
        if fromCamera, count < Self.maximumPhotos {
            alert.addAction(UIAlertAction(title: "Add another photo", style: .default) { [weak self] _ in self?.presentCamera() })
        }
        alert.addAction(UIAlertAction(title: count > 1 ? "Read \(count) photos" : "Read photo", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let jpegs = pendingPhotos
            pendingPhotos = []
            read(jpegs, note: alert?.textFields?.first?.text)
        })
        alert.preferredAction = alert.actions.last
        present(alert, animated: true)
    }

    /// A placeholder line reads "Photo" while the photo model looks at it.
    private func read(_ jpegs: [Data], note: String?) {
        let id = draft.addPhoto()
        photos[id] = jpegs
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { photoNotes[id] = trimmed }
        render()
        onChange()
        sendPhoto(id, jpegs: jpegs)
    }

    private func sendPhoto(_ id: DescribeLine.ID, jpegs: [Data]) {
        guard problem == nil, draft.begin(id) != nil else { return }
        reconfigure(id)
        let estimator = dependencies.foodEstimator
        let library = currentLibrary()
        let note = photoNotes[id]
        Task { [weak self] in
            let result: Result<[Estimate], Error>
            do {
                result = .success(try await estimator.estimate(photos: jpegs, note: note, library: library))
            } catch {
                result = .failure(error)
            }
            self?.receivedPhoto(id, result: result)
        }
    }

    private func receivedPhoto(_ id: DescribeLine.ID, result: Result<[Estimate], Error>) {
        guard draft.finishPhoto(id, result: result) else { return }
        switch result {
        case .success:
            photos[id] = nil
            photoNotes[id] = nil
        case .failure(let error):
            let error = OpenRouterError.from(error)
            if [.noKey, .keyRejected, .limitReached].contains(error) {
                problem = error
            }
            Self.logger.error("Photo failed: \(error.message, privacy: .public)")
        }
        render()
        onChange()
    }

    /// The catalogue as it is now; empty (so nothing matches) if it can't be read.
    private func currentLibrary() -> FoodLibrary {
        do {
            return FoodLibrary(foodItems: try dependencies.store.foodItems(), meals: try dependencies.store.meals())
        } catch {
            Self.logger.error("Failed to read the catalogue: \(error, privacy: .public)")
            return .empty
        }
    }

    private func received(_ id: DescribeLine.ID, sentText: String, result: Result<Estimate, Error>) {
        // Several foods on one line: each becomes its own line and is estimated on its own.
        if case .failure(Estimate.ReplyError.severalFoods(let parts)) = result {
            guard let ids = draft.split(id, sentText: sentText, into: parts) else { return }
            render()
            onChange()
            ids.forEach(send)
            return
        }
        guard draft.finish(id, sentText: sentText, result: result) else { return }
        if case .failure(let error) = result {
            let error = OpenRouterError.from(error)
            if [.noKey, .keyRejected, .limitReached].contains(error) {
                problem = error
                render()
            }
            Self.logger.error("Estimate failed: \(error.message, privacy: .public)")
        }
        reconfigure(id)
        onChange()
    }

    // MARK: - The line page

    private func openLine(_ line: DescribeLine) {
        view.endEditing(true)
        let problem: String?
        switch line.state {
        case .failed(let reason): problem = reason
        case .waiting: problem = "Waiting for a connection. It fills in by itself once there is one."
        case .typing, .checking, .filled: problem = nil
        }
        let id = line.id
        let page = DescribeLineViewController(line: line, problem: problem, onChange: { [weak self] edit in
            self?.edited(id, on: edit)
        }, onTryAgain: { [weak self] in
            self?.navigationController?.popViewController(animated: true)
            self?.send(id)
        }, onReestimate: { [weak self] text in
            self?.navigationController?.popViewController(animated: true)
            self?.reestimate(id, as: text)
        })
        navigationController?.pushViewController(page, animated: true)
    }

    /// The page asked for numbers for a new unit: the line becomes that text ("Pho, 2 cups") and
    /// is estimated again, as if typed.
    private func reestimate(_ id: DescribeLine.ID, as text: String) {
        timers[id]?.cancel()
        guard draft.edit(id, text: text) else { return send(id) }
        syncAddRow()
        reconfigure(id)
        onChange()
        send(id)
    }

    /// The page writes into its line as it changes (DESIGN.md §7a). While it holds nothing
    /// addable (a cleared quantity, nothing typed yet), the line keeps what it had.
    private func edited(_ id: DescribeLine.ID, on edit: DescribeLineEdit) {
        if let estimate = edit.estimate {
            timers[id]?.cancel()
            draft.setEstimate(id, estimate)
        }
        draft.setSaveAsFood(id, edit.saveAsFood && edit.offersSaveAsFood)
        reconfigure(id)
        onChange()
    }

    /// The line's own Save to Foods toggle; the draft keeps it, so the line page agrees.
    private func setSaveAsFood(_ id: DescribeLine.ID, _ saveAsFood: Bool) {
        draft.setSaveAsFood(id, saveAsFood)
        onChange()
    }

    // MARK: - Your foods as you type

    /// Offers the saved foods the line's words start, above the keyboard; none once nothing
    /// matches or the line already is a name (it fills in from Foods by itself).
    private func suggest(for id: DescribeLine.ID, text: String) {
        let suggestions = currentLibrary().suggestions(for: text)
        suggestionBar.show(suggestions)
        suggestingLine = suggestions.isEmpty ? nil : id
        cell(for: id)?.showSuggestions(suggestions.isEmpty ? nil : suggestionBar)
    }

    /// Leaving a line sends it, and its suggestions go with the keyboard.
    private func endedEditing(_ id: DescribeLine.ID) {
        if suggestingLine == id {
            suggestingLine = nil
            cell(for: id)?.showSuggestions(nil)
        }
        send(id)
    }

    /// The line becomes the food's name (after any amount typed) and fills in from Foods.
    private func pick(_ suggestion: FoodLibrary.Suggestion) {
        guard let id = suggestingLine else { return }
        suggestingLine = nil
        cell(for: id)?.showSuggestions(nil)
        timers[id]?.cancel()
        draft.edit(id, text: suggestion.text)
        syncAddRow()
        reconfigure(id)
        send(id)
        onChange()
    }

    private func cell(for id: DescribeLine.ID) -> DescribeLineCell? {
        dataSource.indexPath(for: .line(id)).flatMap { collectionView.cellForItem(at: $0) as? DescribeLineCell }
    }

    // MARK: - Adding a line

    /// The "Add food" row: an empty line at the end, with the keyboard on it.
    private func addLine() {
        let id = draft.insertLine(after: draft.lines.last?.id)
        render()
        onChange()
        focus(id)
    }

    // MARK: - Removing a line

    /// The line at this row when there is something to remove: any line while there are
    /// several, and the last one only once it holds something.
    private func removableLine(at indexPath: IndexPath) -> DescribeLine.ID? {
        guard case .line(let id) = dataSource.itemIdentifier(for: indexPath), let line = draft.line(id) else { return nil }
        return draft.lines.count > 1 || !line.trimmedText.isEmpty ? id : nil
    }

    /// Removes a line for good, with no confirmation: it is cheap to type or take again, and
    /// nothing is logged. A photo still being read is let go (its answer finds no line to
    /// land on); the last line left is emptied instead (`DescribeDraft.removeLine`).
    private func removeLine(_ id: DescribeLine.ID) {
        timers[id]?.cancel()
        timers[id] = nil
        photos[id] = nil
        photoNotes[id] = nil
        draft.removeLine(id)
        render()
        onChange()
    }

    // MARK: - Typing

    private func returned(_ id: DescribeLine.ID) {
        guard draft.line(id)?.trimmedText.isEmpty == false else {
            view.endEditing(true)
            return
        }
        send(id)
        let next = draft.insertLine(after: id)
        render()
        focus(next)
    }

    private func deletedEmpty(_ id: DescribeLine.ID) {
        guard draft.lines.count > 1 else { return }
        timers[id]?.cancel()
        let previous = draft.removeLine(id)
        render()
        if let previous { focus(previous) }
        onChange()
    }

    private func focus(_ id: DescribeLine.ID) {
        guard let indexPath = dataSource.indexPath(for: .line(id)) else { return }
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        collectionView.layoutIfNeeded()
        (collectionView.cellForItem(at: indexPath) as? DescribeLineCell)?.focus()
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.showsSeparators = false
        configuration.backgroundColor = .clear
        // Swipe a line left to remove it; a long swipe removes it at once, as in any list.
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let id = removableLine(at: indexPath) else { return nil }
            let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
                self?.removeLine(id)
                done(true)
            }
            remove.image = UIImage(systemName: "trash.fill")
            let actions = UISwipeActionsConfiguration(actions: [remove])
            actions.performsFirstActionWithFullSwipe = true
            return actions
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
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        collectionView.insetsContentAboveKeyboard(in: view)

        let lineCell = UICollectionView.CellRegistration<DescribeLineCell, DescribeLine.ID> { [weak self] cell, _, id in
            guard let self, let line = draft.line(id) else { return }
            let isOnlyLine = draft.lines.count == 1
            cell.configure(line, placeholder: isOnlyLine ? "2 eggs, toast with butter…" : "Another food", actions: .init(
                onEdit: { [weak self] in self?.edited(id, text: $0) },
                onReturn: { [weak self] in self?.returned(id) },
                onDeleteEmpty: { [weak self] in self?.deletedEmpty(id) },
                onEndEditing: { [weak self] in self?.endedEditing(id) },
                onSaveAsFood: { [weak self] in self?.setSaveAsFood(id, $0) }
            ))
        }
        let addCell = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, _, title in
            cell.contentConfiguration = UIListContentConfiguration.addRow(title)
            cell.backgroundConfiguration = UIBackgroundConfiguration.listCell()
            cell.accessibilityTraits = .button
        }
        let problemCell = UICollectionView.CellRegistration<UICollectionViewListCell, OpenRouterError> { [weak self] cell, _, problem in
            let (title, message) = Self.card(for: problem)
            cell.contentConfiguration = UIHostingConfiguration {
                WarningCard(title: title, message: message, actionTitle: "Open Settings") { self?.openSettings() }
            }
            .margins(.all, 0)
            cell.backgroundConfiguration = .clear()
        }
        let totalCell = UICollectionView.CellRegistration<UICollectionViewListCell, Macros> { [weak self] cell, _, total in
            var content = UIListContentConfiguration.listRow()
            let count = self?.filledCount ?? 0
            content.text = count == 1 ? "1 food to add" : "\(count) foods to add"
            content.secondaryAttributedText = FoodText.styledMacroLineUIKit(total)
            cell.contentConfiguration = content
            cell.backgroundConfiguration = .clear()
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            switch item {
            case .problem:
                return collectionView.dequeueConfiguredReusableCell(using: problemCell, for: indexPath, item: self?.problem ?? .noKey)
            case .line(let id):
                return collectionView.dequeueConfiguredReusableCell(using: lineCell, for: indexPath, item: id)
            case .addRow:
                return collectionView.dequeueConfiguredReusableCell(using: addCell, for: indexPath, item: "Add food")
            case .total:
                return collectionView.dequeueConfiguredReusableCell(using: totalCell, for: indexPath, item: self?.draft.filledTotal ?? .zero)
            }
        }
    }

    private static func card(for problem: OpenRouterError) -> (title: String, message: String) {
        switch problem {
        case .keyRejected:
            return ("OpenRouter rejected the key", "Paste it again in Settings, or make a new one at openrouter.ai. What you type waits here.")
        case .limitReached:
            return ("The key's spending limit is reached", "Raise it at openrouter.ai, or wait for it to reset. What you type waits here.")
        case .noKey, .offline, .failed:
            return ("Add your OpenRouter key", "Describe fills in each food's macros with OpenRouter. Paste a key once in Settings.")
        }
    }

    // MARK: - Rendering

    private func render(animated: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        if problem != nil {
            snapshot.appendSections([.problem])
            snapshot.appendItems([.problem], toSection: .problem)
        }
        snapshot.appendSections([.lines])
        snapshot.appendItems(draft.lines.map { .line($0.id) }, toSection: .lines)
        if showsAddRow { snapshot.appendItems([.addRow], toSection: .lines) }
        if filledCount > 0 {
            snapshot.appendSections([.total])
            snapshot.appendItems([.total], toSection: .total)
        }
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { $0 == .problem || $0 == .total })
        dataSource.apply(snapshot, animatingDifferences: animated && viewIfLoaded?.window != nil)
    }

    /// Whether "Add food" shows: the last line has something in it. With an empty last line
    /// there is already one to type into, so no second way to add one.
    private var showsAddRow: Bool {
        draft.offersAddLine
    }

    /// Adds or takes away the "Add food" row to match the last line, without redrawing the
    /// lines (so a field being typed in keeps its caret).
    private func syncAddRow() {
        var snapshot = dataSource.snapshot()
        let has = snapshot.itemIdentifiers.contains(.addRow)
        guard has != showsAddRow else { return }
        if showsAddRow {
            snapshot.appendItems([.addRow], toSection: .lines)
        } else {
            snapshot.deleteItems([.addRow])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    /// Refreshes one line's caption in place (its field keeps the caret) and the total row.
    private func reconfigure(_ id: DescribeLine.ID) {
        var snapshot = dataSource.snapshot()
        let hasAddRow = snapshot.itemIdentifiers.contains(.addRow)
        if showsAddRow, !hasAddRow {
            snapshot.appendItems([.addRow], toSection: .lines)
        } else if !showsAddRow, hasAddRow {
            snapshot.deleteItems([.addRow])
        }
        let hasTotal = snapshot.sectionIdentifiers.contains(.total)
        if filledCount > 0, !hasTotal {
            snapshot.appendSections([.total])
            snapshot.appendItems([.total], toSection: .total)
        } else if filledCount == 0, hasTotal {
            snapshot.deleteSections([.total])
        } else if hasTotal {
            snapshot.reconfigureItems([.total])
        }
        if snapshot.indexOfItem(.line(id)) != nil {
            snapshot.reconfigureItems([.line(id)])
        }
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

extension DescribeViewController: UICollectionViewDelegate {

    /// Tapping under a line's text opens its page once it has something to show: its
    /// Estimate to adjust, or why it has none, with Try again and fields to type it in.
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if dataSource.itemIdentifier(for: indexPath) == .addRow {
            return addLine()
        }
        guard case .line(let id) = dataSource.itemIdentifier(for: indexPath), let line = draft.line(id) else { return }
        switch line.state {
        case .filled, .failed, .waiting:
            openLine(line)
        case .typing, .checking:
            (collectionView.cellForItem(at: indexPath) as? DescribeLineCell)?.focus()
        }
    }

    /// Press and hold a line for Remove, the same as the swipe.
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first, let id = removableLine(at: indexPath) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Remove", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in self?.removeLine(id) },
            ])
        }
    }
}

extension DescribeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            add([image], fromCamera: true)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension DescribeViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        let providers = results.map(\.itemProvider).filter { $0.canLoadObject(ofClass: UIImage.self) }
        guard !providers.isEmpty else { return }
        // Loaded in the order picked, then read together.
        Task { @MainActor [weak self] in
            var images: [UIImage] = []
            for provider in providers {
                let image: UIImage? = await withCheckedContinuation { continuation in
                    provider.loadObject(ofClass: UIImage.self) { object, error in
                        if object == nil { Self.logger.error("Couldn't load a chosen photo: \(String(describing: error), privacy: .public)") }
                        continuation.resume(returning: object as? UIImage)
                    }
                }
                if let image { images.append(image) }
            }
            guard !images.isEmpty else { return }
            self?.add(images, fromCamera: false)
        }
    }
}

extension Store {

    /// Logs one Describe line as an Entry: through the user's Food Item or Meal when it
    /// matched one (on its own if that has since gone), else saving it to Foods when asked
    /// and no Food Item has its name, else on its own.
    func logDescribed(_ estimate: Estimate, typed: String, savingAsFood: Bool, at instant: Date, in calendar: Calendar = .current) throws {
        let name = estimate.name.isEmpty ? typed : estimate.name
        if savingAsFood, estimate.match == nil, try foodItem(named: name) == nil, let servings = estimate.naturalServings {
            try logEntrySavingFood(name: name, servings: servings, entryServingName: estimate.unit, quantity: estimate.quantity,
                                   macros: estimate.macros, extras: estimate.extras, at: instant, in: calendar)
            return
        }
        if savingAsFood, estimate.match == nil, try foodItem(named: name) == nil {
            let (serving, quantity) = estimate.servingToSave
            try logEntrySavingFood(name: name, serving: serving, quantity: quantity, at: instant, in: calendar)
            return
        }
        do {
            switch estimate.match {
            case .foodItem(let id, let serving):
                // A line in grams of a saved food ("45g granola") logs in grams.
                let grams = estimate.unit.lowercased() == "g" ? estimate.quantity : nil
                try logEntry(foodItem: id, serving: serving, quantity: estimate.quantity, grams: grams, at: instant, in: calendar)
                return
            case .meal(let id):
                try logEntry(meal: id, quantity: estimate.quantity, at: instant, in: calendar)
                return
            case nil:
                break
            }
        } catch is Store.NotFound {
            Logger(category: "Food").info("Matched food is gone; logging the line on its own")
        }
        try logEntry(name: name, servingName: estimate.unit, quantity: estimate.quantity, macros: estimate.macros, extras: estimate.extras, at: instant, in: calendar)
    }
}
