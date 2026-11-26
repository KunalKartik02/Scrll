import Photos
import SwiftUI

struct CleanupView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @StateObject private var scanner = DuplicateScanner()

    @State private var screenshotCount = 0
    @State private var longVideoCount = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DuplicatesView(scanner: scanner)
                    } label: {
                        CleanupRow(
                            symbol: "square.on.square",
                            color: .orange,
                            title: "Duplicates",
                            detail: duplicatesDetail
                        )
                    }
                    NavigationLink {
                        AssetBatchCleanupView(kind: .screenshots)
                    } label: {
                        CleanupRow(
                            symbol: "camera.viewfinder",
                            color: .blue,
                            title: "Screenshots",
                            detail: screenshotCount.counted("screenshot")
                        )
                    }
                    NavigationLink {
                        AssetBatchCleanupView(kind: .longVideos)
                    } label: {
                        CleanupRow(
                            symbol: "film",
                            color: .purple,
                            title: "Long Videos",
                            detail: longVideoCount.counted("video") + " over a minute"
                        )
                    }
                } footer: {
                    Text("Deleted items go to Recently Deleted in the Photos app, where you can recover them for 30 days.")
                }
            }
            .navigationTitle("Clean Up")
            .task(id: library.revision) {
                screenshotCount = library.screenshots().count
                longVideoCount = library.longVideos().count
            }
        }
    }

    private var duplicatesDetail: String {
        switch scanner.phase {
        case .idle:
            return "Find photos that look the same"
        case let .scanning(done, total):
            return "Scanning \(done.formatted()) of \(total.formatted())…"
        case .finished:
            return scanner.groups.isEmpty
                ? "No duplicates found"
                : scanner.groups.count.counted("set") + " found"
        }
    }
}

private struct CleanupRow: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(color, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Grid of a category (screenshots, long videos) with multi-select delete.
struct AssetBatchCleanupView: View {
    enum Kind {
        case screenshots
        case longVideos

        var title: String {
            switch self {
            case .screenshots: return "Screenshots"
            case .longVideos: return "Long Videos"
            }
        }
    }

    let kind: Kind

    @EnvironmentObject private var library: PhotoLibrary
    @EnvironmentObject private var progress: ReviewProgressStore

    @State private var assets: [PHAsset] = []
    @State private var hasLoaded = false
    @State private var selection = Set<String>()
    @State private var viewer: ViewerRoute?
    @State private var alert: AlertMessage?
    @State private var isWorking = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 2)]

    private var allSelected: Bool {
        !assets.isEmpty && selection.count == assets.count
    }

    var body: some View {
        Group {
            if !hasLoaded {
                ProgressView()
            } else if assets.isEmpty {
                ContentUnavailableView(
                    kind == .screenshots ? "No Screenshots" : "No Long Videos",
                    systemImage: "checkmark.circle",
                    description: Text("Nothing to clean up here.")
                )
            } else {
                ScrollView {
                    Text("Tap to select. Long-press to preview.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            GridCell(
                                asset: asset,
                                isSelecting: true,
                                isSelected: selection.contains(asset.localIdentifier)
                            )
                            .onTapGesture { toggle(asset) }
                            .onLongPressGesture {
                                viewer = ViewerRoute(assets: assets, startID: asset.localIdentifier)
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction(named: "Preview") {
                                viewer = ViewerRoute(assets: assets, startID: asset.localIdentifier)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !assets.isEmpty {
                    Button(allSelected ? "Deselect All" : "Select All") {
                        if allSelected {
                            selection.removeAll()
                        } else {
                            selection = Set(assets.map(\.localIdentifier))
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !assets.isEmpty {
                Button(role: .destructive) {
                    Task { await deleteSelection() }
                } label: {
                    Group {
                        if isWorking {
                            ProgressView()
                        } else {
                            Text(selection.isEmpty ? "Select Items to Delete" : "Delete \(selection.count.counted("Item"))")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(selection.isEmpty || isWorking)
                .padding()
                .background(.bar)
            }
        }
        .fullScreenCover(item: $viewer) { route in
            PhotoViewer(assets: route.assets, startID: route.startID)
                .environmentObject(library)
                .environmentObject(progress)
        }
        .task(id: library.revision) {
            assets = kind == .screenshots ? library.screenshots() : library.longVideos()
            selection.formIntersection(assets.map(\.localIdentifier))
            hasLoaded = true
        }
        .errorAlert($alert)
    }

    private func toggle(_ asset: PHAsset) {
        if selection.contains(asset.localIdentifier) {
            selection.remove(asset.localIdentifier)
        } else {
            selection.insert(asset.localIdentifier)
        }
    }

    private func deleteSelection() async {
        let toDelete = assets.filter { selection.contains($0.localIdentifier) }
        guard !toDelete.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            if try await library.delete(toDelete) {
                selection.removeAll()
            }
        } catch {
            alert = AlertMessage("Couldn't Delete", error)
        }
    }
}
