import Foundation

/// Groups photos whose perceptual hashes (and shapes) are close enough to be duplicates.
enum DuplicateGrouper {
    struct Item: Hashable {
        let id: String
        let hash: UInt64
        /// width / height of the photo in pixels.
        let aspectRatio: Double
    }

    /// Facts used to decide which copy in a duplicate group is worth keeping.
    struct Candidate: Equatable {
        let pixelCount: Int
        let isFavorite: Bool
        let creationDate: Date?
    }

    /// Default maximum Hamming distance for two photos to count as duplicates.
    static let defaultThreshold = 4
    /// Maximum relative difference between aspect ratios of duplicates.
    static let aspectTolerance = 0.05

    /// Returns groups of ids (each with at least two members). Members keep their input
    /// order, and groups are ordered by the position of their first member.
    static func groups(_ items: [Item], threshold: Int = defaultThreshold) -> [[String]] {
        guard items.count > 1 else { return [] }

        var parent = Array(0..<items.count)

        func root(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }

        func union(_ a: Int, _ b: Int) {
            let rootA = root(a)
            let rootB = root(b)
            guard rootA != rootB else { return }
            // Keep the smaller index as root so ordering stays stable.
            if rootA < rootB { parent[rootB] = rootA } else { parent[rootA] = rootB }
        }

        for i in 0..<items.count {
            for j in (i + 1)..<items.count where areDuplicates(items[i], items[j], threshold: threshold) {
                union(i, j)
            }
        }

        var membersByRoot: [Int: [Int]] = [:]
        for index in items.indices {
            membersByRoot[root(index), default: []].append(index)
        }

        return membersByRoot.values
            .filter { $0.count > 1 }
            .sorted { $0[0] < $1[0] }
            .map { members in members.map { items[$0].id } }
    }

    static func areDuplicates(_ a: Item, _ b: Item, threshold: Int = defaultThreshold) -> Bool {
        guard PerceptualHash.distance(a.hash, b.hash) <= threshold else { return false }
        let larger = max(a.aspectRatio, b.aspectRatio)
        guard larger > 0 else { return a.aspectRatio == b.aspectRatio }
        return abs(a.aspectRatio - b.aspectRatio) / larger <= aspectTolerance
    }

    /// Index of the copy to keep: highest resolution, then favorites, then the oldest.
    static func preferredIndex(_ candidates: [Candidate]) -> Int? {
        guard !candidates.isEmpty else { return nil }
        var best = 0
        for index in candidates.indices.dropFirst() where isBetter(candidates[index], than: candidates[best]) {
            best = index
        }
        return best
    }

    private static func isBetter(_ a: Candidate, than b: Candidate) -> Bool {
        if a.pixelCount != b.pixelCount { return a.pixelCount > b.pixelCount }
        if a.isFavorite != b.isFavorite { return a.isFavorite }
        switch (a.creationDate, b.creationDate) {
        case let (dateA?, dateB?): return dateA < dateB
        case (.some, .none): return true
        default: return false
        }
    }
}
