import UIKit
import os

/// The Progress Photos grid, pushed from the Train root's chip: thumbnails newest first, each
/// with its Day beneath. `+` takes a photo or picks one from the library. Tapping picks a
/// photo for a compare; picking a second opens the two-up. Long-press views one on its own
/// or deletes it, with confirmation. Reads through the façade on every appearance and after
/// every write.
final class ProgressPhotosViewController: UIViewController {

    private static let logger = Logger(category: "ProgressPhotos")
    private static let columns = 3
    /// How many photos a compare takes.
    private static let compareCount = 2

    private enum Section: Hashable {
        case photos
    }

    private let dependencies: AppDependencies
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, ProgressPhotoRecord.ID>!
    private var photos: [ProgressPhotoRecord.ID: ProgressPhotoRecord] = [:]
    /// Decoded thumbnails; dropped under memory pressure and re-read from the store.
    private var thumbnails: [ProgressPhotoRecord.ID: UIImage] = [:]
    private lazy var picker = ProgressPhotoPicker(presenter: self)
    private let emptyState = CardView.emptyState(
        caption: "Tap + to take a progress photo or pick one from your library.",
        accessibilityLabel: "No progress photos yet. Tap + to take a progress photo or pick one from your library."
    )

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
        title = "Progress Photos"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
        navigationItem.largeTitleDisplayMode = .never

        let takePhoto = UIAction(title: "Take photo", image: UIImage(systemName: "camera")) { [weak self] _ in self?.takePhoto() }
        takePhoto.attributes = ProgressPhotoPicker.isCameraAvailable ? [] : .hidden
        let choose = UIAction(title: "Choose from library", image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in self?.chooseFromLibrary() }
        let add = UIBarButtonItem(systemItem: .add)
        add.menu = UIMenu(children: [takePhoto, choose])
        add.accessibilityLabel = "Add progress photo"
        navigationItem.rightBarButtonItem = add

        configureCollectionView()
        configureEmptyState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clearPicks()
        render()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        thumbnails.removeAll()
    }

    // MARK: - Collection view

    private func configureCollectionView() {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / CGFloat(Self.columns)),
            heightDimension: .estimated(150)
        ))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(150)),
            repeatingSubitem: item,
            count: Self.columns
        )
        group.interItemSpacing = .fixed(Metrics.spaceTight)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Metrics.spaceCard
        section.contentInsets = NSDirectionalEdgeInsets(top: Metrics.spaceCard, leading: Metrics.spaceEdge, bottom: Metrics.spaceCard, trailing: Metrics.spaceEdge)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        collectionView.backgroundColor = .clear
        collectionView.allowsMultipleSelection = true
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let photoCell = UICollectionView.CellRegistration<ProgressPhotoCell, ProgressPhotoRecord.ID> { [weak self] cell, _, id in
            guard let self, let photo = photos[id] else { return }
            cell.configure(thumbnail: thumbnail(for: id), caption: photo.day.shortTitle())
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: photoCell, for: indexPath, item: id)
        }
    }

    /// The empty state (DESIGN.md §1.5) sits over the grid where the first row will be.
    private func configureEmptyState() {
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyState)
        NSLayoutConstraint.activate([
            emptyState.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Metrics.spaceCard),
            emptyState.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Metrics.spaceEdge),
            emptyState.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Metrics.spaceEdge),
        ])
    }

    // MARK: - Rendering

    private func render() {
        let records: [ProgressPhotoRecord]
        do {
            records = try dependencies.store.progressPhotos()
        } catch {
            Self.logger.error("Failed to read Progress Photos: \(error, privacy: .public)")
            return
        }
        photos = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })

        var snapshot = NSDiffableDataSourceSnapshot<Section, ProgressPhotoRecord.ID>()
        snapshot.appendSections([.photos])
        snapshot.appendItems(records.map(\.id), toSection: .photos)
        dataSource.apply(reconfiguringExisting: snapshot, animatingDifferences: viewIfLoaded?.window != nil)

        emptyState.isHidden = !records.isEmpty
        navigationItem.subtitle = Self.subtitle(count: records.count)
    }

    /// "1 photo"; "4 photos · tap two to compare" once a compare is possible; nothing when empty.
    private static func subtitle(count: Int) -> String? {
        guard count > 0 else { return nil }
        let photos = TrainText.count(count, "photo")
        return count >= compareCount ? "\(photos) · tap two to compare" : photos
    }

    private func thumbnail(for id: ProgressPhotoRecord.ID) -> UIImage? {
        if let cached = thumbnails[id] { return cached }
        do {
            let image = try dependencies.store.progressPhotoThumbnail(id).flatMap(UIImage.init)
            thumbnails[id] = image
            return image
        } catch {
            Self.logger.error("Failed to read a thumbnail: \(error, privacy: .public)")
            return nil
        }
    }

    // MARK: - Adding

    private func takePhoto() {
        picker.presentCamera { [weak self] picked in
            if let picked { self?.add(picked) }
        }
    }

    private func chooseFromLibrary() {
        picker.presentLibrary { [weak self] picked in
            if let picked { self?.add(picked) }
        }
    }

    /// Encodes off the main thread (a camera image is large), then stores it on its Day.
    private func add(_ picked: PickedPhoto) {
        Task { [weak self] in
            let encoded = await Task.detached(priority: .userInitiated) { ProgressPhotoEncoder.encode(picked.image) }.value
            guard let self else { return }
            guard let encoded else {
                Self.logger.error("Could not encode the picked photo")
                return
            }
            do {
                try dependencies.store.addProgressPhoto(image: encoded.image, thumbnail: encoded.thumbnail, on: picked.day)
            } catch {
                Self.logger.error("Failed to add Progress Photo: \(error, privacy: .public)")
                return
            }
            render()
            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: true)
        }
    }

    // MARK: - Compare and delete

    private func pickedIDs() -> [ProgressPhotoRecord.ID] {
        (collectionView.indexPathsForSelectedItems ?? []).compactMap { dataSource.itemIdentifier(for: $0) }
    }

    private func clearPicks() {
        for indexPath in collectionView.indexPathsForSelectedItems ?? [] {
            collectionView.deselectItem(at: indexPath, animated: false)
        }
    }

    private func showCompare(_ ids: [ProgressPhotoRecord.ID]) {
        navigationController?.pushViewController(ProgressPhotoCompareViewController(dependencies: dependencies, photoIDs: ids), animated: true)
    }

    private func confirmDelete(_ id: ProgressPhotoRecord.ID) {
        let alert = UIAlertController(
            title: "Delete this photo?",
            message: "It is removed from every device. This cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in self?.delete(id) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func delete(_ id: ProgressPhotoRecord.ID) {
        do {
            try dependencies.store.deleteProgressPhoto(id)
        } catch {
            Self.logger.error("Failed to delete Progress Photo: \(error, privacy: .public)")
            return
        }
        thumbnails[id] = nil
        render()
    }
}

extension ProgressPhotosViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        pickedIDs().count < Self.compareCount
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let picked = pickedIDs()
        guard picked.count == Self.compareCount else { return }
        showCompare(picked)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let view = UIAction(title: "View", image: UIImage(systemName: "eye")) { _ in self?.showCompare([id]) }
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in self?.confirmDelete(id) }
            return UIMenu(children: [view, delete])
        }
    }
}
