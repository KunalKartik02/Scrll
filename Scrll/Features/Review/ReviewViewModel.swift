import Photos
import SwiftUI

/// Drives a swipe-review pass. Keeps and favorites are saved immediately; deletions are
/// collected and only carried out when the person confirms in the summary.
@MainActor
final class ReviewViewModel: ObservableObject {
    @Published private(set) var session: ReviewSession
    @Published var lastError: AlertMessage?

    private var assetsByID: [String: PHAsset]
    /// Photos this pass turned into favorites, so undo can turn them back.
    private var favoritedHere = Set<String>()

    init(assets: [PHAsset]) {
        session = ReviewSession(ids: assets.map(\.localIdentifier))
        assetsByID = Dictionary(assets.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var currentAsset: PHAsset? { session.current.flatMap { assetsByID[$0] } }
    var nextAsset: PHAsset? { session.next.flatMap { assetsByID[$0] } }

    var trashedAssets: [PHAsset] {
        session.ids(withDecision: .trash).compactMap { assetsByID[$0] }
    }

    /// Every photo decided in this pass (for the summary grid).
    var decidedAssets: [PHAsset] {
        session.history.compactMap { assetsByID[$0.id] }
    }

    func decision(for asset: PHAsset) -> ReviewDecision? {
        session.decision(for: asset.localIdentifier)
    }

    func decide(_ decision: ReviewDecision, library: PhotoLibrary, progress: ReviewProgressStore) {
        guard let asset = currentAsset, let entry = session.decide(decision) else { return }
        switch decision {
        case .keep:
            progress.markReviewed([entry.id])
        case .favorite:
            progress.markReviewed([entry.id])
            if !asset.isFavorite {
                favoritedHere.insert(entry.id)
                Task { await setFavorite(asset, true, library: library) }
            }
        case .trash:
            break
        }
    }

    func undo(library: PhotoLibrary, progress: ReviewProgressStore) {
        guard let entry = session.undo() else { return }
        revertSideEffects(of: entry, library: library, progress: progress)
    }

    /// Toggles a photo in the summary between "delete" and "keep".
    func toggleTrash(_ asset: PHAsset, library: PhotoLibrary, progress: ReviewProgressStore) {
        let id = asset.localIdentifier
        guard let current = session.decision(for: id) else { return }
        if current == .trash {
            session.setDecision(.keep, for: id)
            progress.markReviewed([id])
        } else {
            if let entry = session.history.first(where: { $0.id == id }) {
                revertSideEffects(of: entry, library: library, progress: progress)
            }
            session.setDecision(.trash, for: id)
        }
    }

    /// Deletes everything marked for deletion. Returns `true` when done (or nothing to do),
    /// `false` if the person cancelled the system confirmation.
    func commitDeletions(library: PhotoLibrary) async -> Bool {
        let assets = trashedAssets
        guard !assets.isEmpty else { return true }
        do {
            let deleted = try await library.delete(assets)
            if deleted {
                session.removeDecisions(for: Set(assets.map(\.localIdentifier)))
            }
            return deleted
        } catch {
            lastError = AlertMessage("Couldn't Delete Photos", error)
            return false
        }
    }

    private func revertSideEffects(of entry: ReviewSession.Entry, library: PhotoLibrary, progress: ReviewProgressStore) {
        switch entry.decision {
        case .keep:
            progress.unmark([entry.id])
        case .favorite:
            progress.unmark([entry.id])
            if favoritedHere.remove(entry.id) != nil, let asset = assetsByID[entry.id] {
                Task { await setFavorite(asset, false, library: library) }
            }
        case .trash:
            break
        }
    }

    private func setFavorite(_ asset: PHAsset, _ value: Bool, library: PhotoLibrary) async {
        do {
            try await library.setFavorite([asset], to: value)
        } catch {
            lastError = AlertMessage("Couldn't Update Favorite", error)
        }
    }
}
