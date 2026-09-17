import CoreData

/// The façade's Progress Photo surface (CONTEXT.md "Progress Photo"). A photo's bytes are an
/// external-binary attribute so CloudKit syncs them as an asset (ADR 0002); the grid reads
/// the small inline thumbnail instead, and the listing and count read neither.
extension Store {

    /// Stores a photo taken on `day` (the local Day at write time, ADR 0005). `image` is the
    /// full-size encoding; `thumbnail` the small one the grid shows.
    @discardableResult
    func addProgressPhoto(image: Data, thumbnail: Data, on day: Day) throws -> ProgressPhotoRecord {
        let photo = ProgressPhoto(context: context)
        photo.id = UUID()
        photo.day = day.rawValue
        photo.imageData = image
        photo.thumbnailData = thumbnail
        try save()
        return ProgressPhotoRecord(photo)!
    }

    /// Every Progress Photo, newest Day first (latest added first within a Day). Fetched as
    /// rows of just the record's columns, so neither the image nor the thumbnail is loaded.
    func progressPhotos() throws -> [ProgressPhotoRecord] {
        let request = NSFetchRequest<NSDictionary>(entityName: "ProgressPhoto")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["id", "day", "modifiedAt"]
        request.sortDescriptors = [
            NSSortDescriptor(key: "day", ascending: false),
            NSSortDescriptor(key: "modifiedAt", ascending: false),
        ]
        return try context.fetch(request).compactMap(ProgressPhotoRecord.init)
    }

    /// How many Progress Photos there are: the Train chip's subtitle.
    func progressPhotoCount() throws -> Int {
        try context.count(for: ProgressPhoto.fetchRequest())
    }

    func progressPhoto(_ id: ProgressPhotoRecord.ID) throws -> ProgressPhotoRecord? {
        try fetchProgressPhoto(id).flatMap(ProgressPhotoRecord.init)
    }

    /// The full-size bytes, for the compare screen.
    func progressPhotoImage(_ id: ProgressPhotoRecord.ID) throws -> Data? {
        try fetchProgressPhoto(id)?.imageData
    }

    /// The thumbnail bytes, for the grid.
    func progressPhotoThumbnail(_ id: ProgressPhotoRecord.ID) throws -> Data? {
        try fetchProgressPhoto(id)?.thumbnailData
    }

    /// Removes the photo and its bytes. Nothing refers to a Progress Photo, so unlike the
    /// catalogue it is deleted, not archived.
    func deleteProgressPhoto(_ id: ProgressPhotoRecord.ID) throws {
        guard let photo = try fetchProgressPhoto(id) else { return }
        context.delete(photo)
        try save()
    }

    private func fetchProgressPhoto(_ id: ProgressPhotoRecord.ID) throws -> ProgressPhoto? {
        let request = ProgressPhoto.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

/// A Progress Photo as read through the façade: its identity and Day, never its bytes.
struct ProgressPhotoRecord: Hashable, Identifiable {
    let id: UUID
    let day: Day
    let modifiedAt: Date
}

private extension ProgressPhotoRecord {
    init?(_ object: ProgressPhoto) {
        guard let id = object.id, let raw = object.day, let day = Day(rawValue: raw), let modifiedAt = object.modifiedAt else { return nil }
        self.init(id: id, day: day, modifiedAt: modifiedAt)
    }

    /// From a `propertiesToFetch` row of the listing.
    init?(_ row: NSDictionary) {
        guard let id = row["id"] as? UUID, let raw = row["day"] as? String, let day = Day(rawValue: raw), let modifiedAt = row["modifiedAt"] as? Date else { return nil }
        self.init(id: id, day: day, modifiedAt: modifiedAt)
    }
}
