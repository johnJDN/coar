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
    private var photos: [DescribeLine.ID: Data] = [:]
    private var collectionView: UICollectionView!
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
        guard draft.edit(id, text: text) else { return }
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
        if let jpeg = photos[id] {
            sendPhoto(id, jpeg: jpeg)
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
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    func choosePhoto() {
        view.endEditing(true)
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    /// A placeholder line reads "Photo" while the photo model looks at it.
    private func add(_ image: UIImage) {
        guard let jpeg = FoodPhoto.jpeg(from: image) else {
            Self.logger.error("Couldn't encode the photo")
            return
        }
        let id = draft.addPhoto()
        photos[id] = jpeg
        render()
        onChange()
        sendPhoto(id, jpeg: jpeg)
    }

    private func sendPhoto(_ id: DescribeLine.ID, jpeg: Data) {
        guard problem == nil, draft.begin(id) != nil else { return }
        reconfigure(id)
        let estimator = dependencies.foodEstimator
        let library = currentLibrary()
        Task { [weak self] in
            let result: Result<[Estimate], Error>
            do {
                result = .success(try await estimator.estimate(photo: jpeg, library: library))
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
        })
        navigationController?.pushViewController(page, animated: true)
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
                onEndEditing: { [weak self] in self?.send(id) },
                onSaveAsFood: { [weak self] in self?.setSaveAsFood(id, $0) }
            ))
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
        if filledCount > 0 {
            snapshot.appendSections([.total])
            snapshot.appendItems([.total], toSection: .total)
        }
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { $0 == .problem || $0 == .total })
        dataSource.apply(snapshot, animatingDifferences: animated && viewIfLoaded?.window != nil)
    }

    /// Refreshes one line's caption in place (its field keeps the caret) and the total row.
    private func reconfigure(_ id: DescribeLine.ID) {
        var snapshot = dataSource.snapshot()
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
        guard case .line(let id) = dataSource.itemIdentifier(for: indexPath), let line = draft.line(id) else { return }
        switch line.state {
        case .filled, .failed, .waiting:
            openLine(line)
        case .typing, .checking:
            (collectionView.cellForItem(at: indexPath) as? DescribeLineCell)?.focus()
        }
    }
}

extension DescribeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            add(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension DescribeViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                guard let image = object as? UIImage else {
                    Self.logger.error("Couldn't load the chosen photo: \(String(describing: error), privacy: .public)")
                    return
                }
                self?.add(image)
            }
        }
    }
}

extension Store {

    /// Logs one Describe line as an Entry: through the user's Food Item or Meal when it
    /// matched one (on its own if that has since gone), else saving it to Foods when asked
    /// and no Food Item has its name, else on its own.
    func logDescribed(_ estimate: Estimate, typed: String, savingAsFood: Bool, at instant: Date, in calendar: Calendar = .current) throws {
        let name = estimate.name.isEmpty ? typed : estimate.name
        if savingAsFood, estimate.match == nil, try foodItem(named: name) == nil {
            let (serving, quantity) = estimate.servingToSave
            try logEntrySavingFood(name: name, serving: serving, quantity: quantity, at: instant, in: calendar)
            return
        }
        do {
            switch estimate.match {
            case .foodItem(let id, let serving):
                try logEntry(foodItem: id, serving: serving, quantity: estimate.quantity, at: instant, in: calendar)
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
        try logEntry(name: name, servingName: estimate.unit, quantity: estimate.quantity, macros: estimate.macros, at: instant, in: calendar)
    }
}
