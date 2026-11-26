import Photos
import UIKit

struct MonthSection: Identifiable {
    let month: YearMonth?
    let assets: [PHAsset]

    var id: String { month?.key ?? "undated" }
    var title: String { month?.title() ?? "Undated" }
    var assetIDs: [String] { assets.map(\.localIdentifier) }
}

struct AlbumInfo: Identifiable, Hashable {
    let collection: PHAssetCollection
    let count: Int
    let cover: PHAsset?

    var id: String { collection.localIdentifier }
    var title: String { collection.localizedTitle ?? "Untitled Album" }
}

/// Single source of truth for the person's photo library. Wraps PhotoKit, keeps a
/// month-grouped snapshot up to date, and performs all edits through the system so
/// iOS can show its own confirmation for deletions.
@MainActor
final class PhotoLibrary: NSObject, ObservableObject {
    @Published private(set) var status: PHAuthorizationStatus
    @Published private(set) var sections: [MonthSection] = []
    @Published private(set) var allAssets: [PHAsset] = []
    @Published private(set) var albums: [AlbumInfo] = []
    @Published private(set) var isLoading = false
    /// Increments every time the snapshot is rebuilt; views use it to refresh derived data.
    @Published private(set) var revision = 0

    private var isObserving = false
    private var reloadTask: Task<Void, Never>?
    private var pendingReload: Task<Void, Never>?

    override init() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        super.init()
        if hasAccess {
            beginObserving()
            reload()
        }
    }

    var hasAccess: Bool { status == .authorized || status == .limited }
    var isLimited: Bool { status == .limited }

    // MARK: - Authorization

    func requestAccess() async {
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        apply(newStatus)
    }

    /// Re-reads the authorization status (the person may have changed it in Settings).
    func refreshStatus() {
        apply(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private func apply(_ newStatus: PHAuthorizationStatus) {
        let changed = newStatus != status
        status = newStatus
        guard hasAccess else {
            if changed {
                sections = []
                allAssets = []
                albums = []
            }
            return
        }
        beginObserving()
        if changed || revision == 0 {
            reload()
        }
    }

    private func beginObserving() {
        guard !isObserving else { return }
        PHPhotoLibrary.shared().register(self)
        isObserving = true
    }

    // MARK: - Loading

    func reload() {
        guard hasAccess else { return }
        reloadTask?.cancel()
        isLoading = true
        reloadTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .userInitiated) {
                PhotoLibrary.loadSnapshot()
            }.value
            guard let self, !Task.isCancelled else { return }
            self.sections = snapshot.sections
            self.allAssets = snapshot.allAssets
            self.albums = snapshot.albums
            self.isLoading = false
            self.revision += 1
        }
    }

    fileprivate func scheduleReload() {
        pendingReload?.cancel()
        pendingReload = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }

    private struct Snapshot: @unchecked Sendable {
        let sections: [MonthSection]
        let allAssets: [PHAsset]
        let albums: [AlbumInfo]
    }

    nonisolated private static func loadSnapshot() -> Snapshot {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }

        let sections = MonthGrouping.group(assets) { $0.creationDate }
            .map { MonthSection(month: $0.month, assets: $0.items) }

        return Snapshot(sections: sections, allAssets: assets, albums: fetchAlbums())
    }

    nonisolated private static func fetchAlbums() -> [AlbumInfo] {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var albums: [AlbumInfo] = []
        collections.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: nil).count
            let cover = PHAsset.fetchKeyAssets(in: collection, options: nil)?.firstObject
            albums.append(AlbumInfo(collection: collection, count: count, cover: cover))
        }
        return albums.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    // MARK: - Queries

    func assets(in collection: PHAssetCollection) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return Self.array(from: PHAsset.fetchAssets(in: collection, options: options))
    }

    func screenshots() -> [PHAsset] {
        guard let album = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil
        ).firstObject else { return [] }
        return assets(in: album)
    }

    /// Videos at least `minimumDuration` seconds long, longest first.
    func longVideos(minimumDuration: TimeInterval = 60) -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND duration >= %f",
            PHAssetMediaType.video.rawValue,
            minimumDuration
        )
        let videos = Self.array(from: PHAsset.fetchAssets(with: options))
        return videos.sorted { $0.duration > $1.duration }
    }

    /// All still photos, oldest first (used by the duplicate scanner).
    func allPhotos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return Self.array(from: PHAsset.fetchAssets(with: options))
    }

    func asset(withID id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    nonisolated static func array(from result: PHFetchResult<PHAsset>) -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    // MARK: - Changes

    /// Deletes assets. iOS asks the person to confirm. Returns `false` if they cancelled.
    @discardableResult
    func delete(_ assets: [PHAsset]) async throws -> Bool {
        guard !assets.isEmpty else { return true }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
            return true
        } catch let error as NSError
            where error.domain == PHPhotosErrorDomain
            && error.code == PHPhotosError.Code.userCancelled.rawValue {
            return false
        }
    }

    func setFavorite(_ assets: [PHAsset], to isFavorite: Bool) async throws {
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            for asset in assets {
                PHAssetChangeRequest(for: asset).isFavorite = isFavorite
            }
        }
    }

    func createAlbum(named title: String, with assets: [PHAsset] = []) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: trimmed)
            if !assets.isEmpty {
                request.addAssets(assets as NSArray)
            }
        }
    }

    func add(_ assets: [PHAsset], to collection: PHAssetCollection) async throws {
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest(for: collection)?.addAssets(assets as NSArray)
        }
    }

    func remove(_ assets: [PHAsset], from collection: PHAssetCollection) async throws {
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest(for: collection)?.removeAssets(assets as NSArray)
        }
    }

    func rename(_ collection: PHAssetCollection, to title: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest(for: collection)?.title = trimmed
        }
    }

    /// Deletes an album. The photos inside it stay in the library.
    @discardableResult
    func deleteAlbum(_ collection: PHAssetCollection) async throws -> Bool {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.deleteAssetCollections([collection] as NSArray)
            }
            return true
        } catch let error as NSError
            where error.domain == PHPhotosErrorDomain
            && error.code == PHPhotosError.Code.userCancelled.rawValue {
            return false
        }
    }
}

extension PhotoLibrary: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            self?.scheduleReload()
        }
    }
}
