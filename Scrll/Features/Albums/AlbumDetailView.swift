import Photos
import SwiftUI

struct AlbumDetailView: View {
    let albumID: String

    @EnvironmentObject private var library: PhotoLibrary
    @EnvironmentObject private var progress: ReviewProgressStore
    @Environment(\.dismiss) private var dismiss

    @State private var assets: [PHAsset] = []
    @State private var isSelecting = false
    @State private var selection = Set<String>()
    @State private var viewer: ViewerRoute?
    @State private var alert: AlertMessage?
    @State private var isWorking = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 2)]

    private var album: AlbumInfo? {
        library.albums.first { $0.id == albumID }
    }

    var body: some View {
        Group {
            if assets.isEmpty {
                ContentUnavailableView {
                    Label("Empty Album", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Select photos in your Library and choose Add to Album.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            Button {
                                tap(asset)
                            } label: {
                                GridCell(
                                    asset: asset,
                                    isSelecting: isSelecting,
                                    isSelected: selection.contains(asset.localIdentifier)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle(album?.title ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !assets.isEmpty {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        selection.removeAll()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                HStack {
                    Text(selection.count.counted("Item") + " Selected")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Remove from Album", role: .destructive) {
                        Task { await removeSelection() }
                    }
                    .disabled(selection.isEmpty || isWorking)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .fullScreenCover(item: $viewer) { route in
            PhotoViewer(assets: route.assets, startID: route.startID)
                .environmentObject(library)
                .environmentObject(progress)
        }
        .task(id: library.revision) {
            guard let album else {
                // The album was deleted (possibly in the Photos app).
                if library.revision > 0 { dismiss() }
                return
            }
            assets = library.assets(in: album.collection)
            selection.formIntersection(assets.map(\.localIdentifier))
        }
        .errorAlert($alert)
    }

    private func tap(_ asset: PHAsset) {
        if isSelecting {
            if selection.contains(asset.localIdentifier) {
                selection.remove(asset.localIdentifier)
            } else {
                selection.insert(asset.localIdentifier)
            }
        } else {
            viewer = ViewerRoute(assets: assets, startID: asset.localIdentifier)
        }
    }

    private func removeSelection() async {
        guard let album else { return }
        let toRemove = assets.filter { selection.contains($0.localIdentifier) }
        isWorking = true
        defer { isWorking = false }
        do {
            try await library.remove(toRemove, from: album.collection)
            selection.removeAll()
            isSelecting = false
        } catch {
            alert = AlertMessage("Couldn't Remove Photos", error)
        }
    }
}
