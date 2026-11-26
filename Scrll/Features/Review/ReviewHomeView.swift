import Photos
import SwiftUI

struct ReviewHomeView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @EnvironmentObject private var progress: ReviewProgressStore

    @State private var activeReview: ReviewRoute?

    private var totalReviewed: Int {
        progress.reviewedCount(in: library.allAssets.map(\.localIdentifier))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ReviewIntroCard(
                        reviewed: totalReviewed,
                        total: library.allAssets.count,
                        onShuffle: startShuffle
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if library.sections.isEmpty {
                    Section {
                        Text(library.isLoading ? "Loading…" : "No photos to review.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("By Month") {
                        ForEach(library.sections) { section in
                            MonthReviewRow(
                                section: section,
                                reviewed: progress.reviewedCount(in: section.assetIDs)
                            ) {
                                start(section)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review")
            .fullScreenCover(item: $activeReview) { route in
                SwipeReviewView(title: route.title, assets: route.assets)
                    .environmentObject(library)
                    .environmentObject(progress)
            }
        }
    }

    private func start(_ section: MonthSection) {
        let unreviewed = section.assets.filter { !progress.isReviewed($0.localIdentifier) }
        // A fully reviewed month can be reviewed again from the start.
        let assets = unreviewed.isEmpty ? section.assets : unreviewed
        guard !assets.isEmpty else { return }
        activeReview = ReviewRoute(title: section.title, assets: assets)
    }

    private func startShuffle() {
        let pool = library.allAssets.filter { !progress.isReviewed($0.localIdentifier) }
        let picked = Array(pool.shuffled().prefix(30))
        guard !picked.isEmpty else { return }
        activeReview = ReviewRoute(title: "Shuffle", assets: picked)
    }
}

struct ReviewRoute: Identifiable {
    let id = UUID()
    let title: String
    let assets: [PHAsset]
}

private struct ReviewIntroCard: View {
    let reviewed: Int
    let total: Int
    var onShuffle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                Label("Delete", systemImage: "arrow.left")
                    .foregroundStyle(.red)
                Label("Keep", systemImage: "arrow.right")
                    .foregroundStyle(.green)
                Label("Favorite", systemImage: "arrow.up")
                    .foregroundStyle(.pink)
            }
            .font(.subheadline.weight(.semibold))

            Text("Pick a month and swipe through it. Nothing is deleted until you confirm at the end.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if total > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(reviewed), total: Double(max(total, 1)))
                    Text("\(reviewed.formatted()) of \(total.counted("item")) reviewed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onShuffle) {
                Label("Shuffle 30 Unreviewed", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reviewed >= total)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .padding(.vertical, 4)
    }
}

private struct MonthReviewRow: View {
    let section: MonthSection
    let reviewed: Int
    var onStart: () -> Void

    private var total: Int { section.assets.count }
    private var isDone: Bool { reviewed >= total }

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 12) {
                HStack(spacing: -14) {
                    ForEach(section.assets.prefix(3), id: \.localIdentifier) { asset in
                        AssetThumbnail(asset: asset, pointSize: 44, showsBadges: false)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.systemBackground), lineWidth: 2))
                    }
                }
                .frame(width: 70, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.body.weight(.semibold))
                    ProgressView(value: Double(reviewed), total: Double(max(total, 1)))
                        .tint(isDone ? Color.green : Color.accentColor)
                    Text(isDone ? "All \(total.formatted()) reviewed" : "\(reviewed.formatted()) of \(total.formatted()) reviewed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: isDone ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(isDone ? Color.green : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(isDone ? "Review this month again" : "Start reviewing this month")
    }
}
