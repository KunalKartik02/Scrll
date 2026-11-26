import Foundation

/// Remembers which photos the person has already reviewed and kept, so review passes
/// skip them next time. Stored as a small JSON file on the device only.
@MainActor
final class ReviewProgressStore: ObservableObject {
    @Published private(set) var reviewed: Set<String>

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? ReviewProgressStore.defaultFileURL()
        self.fileURL = url
        self.reviewed = ReviewProgressStore.load(from: url)
    }

    nonisolated static func defaultFileURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("review-progress.json")
    }

    func isReviewed(_ id: String) -> Bool {
        reviewed.contains(id)
    }

    func reviewedCount(in ids: [String]) -> Int {
        ids.reduce(0) { $0 + (reviewed.contains($1) ? 1 : 0) }
    }

    func markReviewed(_ ids: [String]) {
        let before = reviewed.count
        reviewed.formUnion(ids)
        if reviewed.count != before { save() }
    }

    func unmark(_ ids: [String]) {
        let before = reviewed.count
        reviewed.subtract(ids)
        if reviewed.count != before { save() }
    }

    func reset() {
        reviewed.removeAll()
        save()
    }

    private func save() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Array(reviewed).sorted())
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Progress is a convenience; failing to save must never break the app.
            #if DEBUG
            print("ReviewProgressStore: could not save – \(error)")
            #endif
        }
    }

    private static func load(from url: URL) -> Set<String> {
        guard let data = try? Data(contentsOf: url),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(ids)
    }
}
