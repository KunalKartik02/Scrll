import Photos

struct DuplicateGroup: Identifiable {
    let assets: [PHAsset]
    /// ids of the copies the person wants to keep (at least one).
    var keep: Set<String>

    var id: String { assets.first?.localIdentifier ?? UUID().uuidString }
    var assetsToDelete: [PHAsset] { assets.filter { !keep.contains($0.localIdentifier) } }

    mutating func toggleKeep(_ id: String) {
        if keep.contains(id) {
            // Never allow a group where every copy would be deleted.
            guard keep.count > 1 else { return }
            keep.remove(id)
        } else {
            keep.insert(id)
        }
    }
}

/// Finds near-identical photos on the device using perceptual hashes.
@MainActor
final class DuplicateScanner: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning(done: Int, total: Int)
        case finished
    }

    @Published private(set) var phase: Phase = .idle
    @Published var groups: [DuplicateGroup] = []

    private var task: Task<Void, Never>?
    private let cache = HashCache()

    var isScanning: Bool {
        if case .scanning = phase { return true }
        return false
    }

    var deletableCount: Int {
        groups.reduce(0) { $0 + $1.assetsToDelete.count }
    }

    func start(using library: PhotoLibrary) {
        task?.cancel()
        groups = []
        let photos = library.allPhotos()
        task = Task { [weak self] in
            await self?.scan(photos)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    /// Removes deleted assets from the results and drops groups that are no longer duplicates.
    func removeDeleted(_ ids: Set<String>) {
        groups = groups.compactMap { group in
            let remaining = group.assets.filter { !ids.contains($0.localIdentifier) }
            guard remaining.count > 1 else { return nil }
            var keep = group.keep.intersection(remaining.map(\.localIdentifier))
            if keep.isEmpty, let first = remaining.first { keep.insert(first.localIdentifier) }
            return DuplicateGroup(assets: remaining, keep: keep)
        }
    }

    private func scan(_ photos: [PHAsset]) async {
        let total = photos.count
        phase = .scanning(done: 0, total: total)

        var items: [DuplicateGrouper.Item] = []
        items.reserveCapacity(total)

        for (index, asset) in photos.enumerated() {
            if Task.isCancelled { return }

            let key = HashCache.key(for: asset)
            var hash = cache.value(for: key)
            if hash == nil, let image = await ImageLoader.shared.hashingImage(for: asset) {
                hash = PerceptualHash.dHash(image)
                if let hash { cache.set(hash, for: key) }
            }
            if let hash {
                let aspect = asset.pixelHeight > 0
                    ? Double(asset.pixelWidth) / Double(asset.pixelHeight)
                    : 0
                items.append(.init(id: asset.localIdentifier, hash: hash, aspectRatio: aspect))
            }

            if index % 20 == 0 || index == total - 1 {
                phase = .scanning(done: index + 1, total: total)
                await Task.yield()
            }
        }

        cache.save()
        guard !Task.isCancelled else { return }

        let finalItems = items
        let idGroups = await Task.detached(priority: .userInitiated) {
            DuplicateGrouper.groups(finalItems)
        }.value
        guard !Task.isCancelled else { return }

        let byID = Dictionary(photos.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        groups = idGroups.compactMap { ids in
            let assets = ids.compactMap { byID[$0] }
            guard assets.count > 1 else { return nil }
            let candidates = assets.map {
                DuplicateGrouper.Candidate(
                    pixelCount: $0.pixelWidth * $0.pixelHeight,
                    isFavorite: $0.isFavorite,
                    creationDate: $0.creationDate
                )
            }
            let keepIndex = DuplicateGrouper.preferredIndex(candidates) ?? 0
            return DuplicateGroup(assets: assets, keep: [assets[keepIndex].localIdentifier])
        }
        phase = .finished
    }
}

/// Persists perceptual hashes so repeat scans only hash new or edited photos.
/// Used only from the main actor (by `DuplicateScanner`).
final class HashCache {
    private var storage: [String: String]
    private var isDirty = false
    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent("photo-hashes.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            storage = decoded
        } else {
            storage = [:]
        }
    }

    static func key(for asset: PHAsset) -> String {
        let modified = asset.modificationDate?.timeIntervalSince1970 ?? 0
        return "\(asset.localIdentifier)#\(Int64(modified))"
    }

    func value(for key: String) -> UInt64? {
        storage[key].flatMap { UInt64($0, radix: 16) }
    }

    func set(_ value: UInt64, for key: String) {
        storage[key] = String(value, radix: 16)
        isDirty = true
    }

    func save() {
        guard isDirty else { return }
        if let data = try? JSONEncoder().encode(storage) {
            try? data.write(to: fileURL, options: .atomic)
            isDirty = false
        }
    }
}
