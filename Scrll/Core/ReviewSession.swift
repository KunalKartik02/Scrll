import Foundation

enum ReviewDecision: String, Codable, CaseIterable {
    case keep
    case trash
    case favorite
}

/// The state of one swipe-review pass over a list of photos, with unlimited undo.
struct ReviewSession: Equatable {
    struct Entry: Equatable {
        let id: String
        var decision: ReviewDecision
    }

    /// Photos to review, in order, without duplicates.
    let ids: [String]
    /// Decisions made so far, in the order they were made.
    private(set) var history: [Entry] = []

    init(ids: [String]) {
        var seen = Set<String>()
        self.ids = ids.filter { seen.insert($0).inserted }
    }

    var total: Int { ids.count }
    var reviewedCount: Int { history.count }
    var isComplete: Bool { history.count >= ids.count }

    var current: String? {
        history.count < ids.count ? ids[history.count] : nil
    }

    /// The photo after the current one, if any.
    var next: String? {
        let index = history.count + 1
        return index < ids.count ? ids[index] : nil
    }

    var progress: Double {
        total == 0 ? 1 : Double(reviewedCount) / Double(total)
    }

    /// Records a decision for the current photo and advances.
    @discardableResult
    mutating func decide(_ decision: ReviewDecision) -> Entry? {
        guard let id = current else { return nil }
        let entry = Entry(id: id, decision: decision)
        history.append(entry)
        return entry
    }

    /// Reverts the most recent decision. Returns the reverted entry.
    @discardableResult
    mutating func undo() -> Entry? {
        history.popLast()
    }

    var canUndo: Bool { !history.isEmpty }

    /// Changes an earlier decision (for example, rescuing a photo from the trash pile).
    mutating func setDecision(_ decision: ReviewDecision, for id: String) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].decision = decision
    }

    func decision(for id: String) -> ReviewDecision? {
        history.first(where: { $0.id == id })?.decision
    }

    func ids(withDecision decision: ReviewDecision) -> [String] {
        history.filter { $0.decision == decision }.map(\.id)
    }

    /// Removes photos that no longer exist (e.g. after they were deleted).
    mutating func removeDecisions(for removedIDs: Set<String>) {
        history.removeAll { removedIDs.contains($0.id) }
    }
}
