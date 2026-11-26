import Photos
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @EnvironmentObject private var progress: ReviewProgressStore

    @State private var isSelecting = false
    @State private var selection = Set<String>()
    @State private var viewer: ViewerRoute?
    @State private var albumPickerAssets: AssetBatch?
    @State private var alert: AlertMessage?
    @State private var isWorking = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 2)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Library")
                .toolbar { toolbar }
                .safeAreaInset(edge: .bottom) {
                    if isSelecting {
                        SelectionActionBar(
                            count: selection.count,
                            isWorking: isWorking,
                            onAddToAlbum: { albumPickerAssets = AssetBatch(assets: selectedAssets) },
                            onFavorite: { Task { await favoriteSelection() } },
                            onDelete: { Task { await deleteSelection() } }
                        )
                    }
                }
                .fullScreenCover(item: $viewer) { route in
                    PhotoViewer(assets: route.assets, startID: route.startID)
                        .environmentObject(library)
                        .environmentObject(progress)
                }
                .sheet(item: $albumPickerAssets) { batch in
                    AlbumPickerSheet(assets: batch.assets) {
                        endSelection()
                    }
                    .environmentObject(library)
                }
                .errorAlert($alert)
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.sections.isEmpty {
            if library.isLoading || library.revision == 0 {
                ProgressView("Loading your photos…")
            } else {
                ContentUnavailableView {
                    Label("No Photos", systemImage: "photo")
                } description: {
                    Text(library.isLimited
                         ? "You've shared no photos with Tidyroll yet."
                         : "Photos you take or save will appear here.")
                } actions: {
                    if library.isLimited {
                        Button("Choose Photos") { SystemActions.presentLimitedLibraryPicker() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            if library.isLimited {
                LimitedAccessBanner()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            LazyVGrid(columns: columns, spacing: 2, pinnedViews: [.sectionHeaders]) {
                ForEach(library.sections) { section in
                    Section {
                        ForEach(section.assets, id: \.localIdentifier) { asset in
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
                    } header: {
                        sectionHeader(section)
                    }
                }
            }
            Text(library.allAssets.count.counted("item"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 20)
        }
    }

    private func sectionHeader(_ section: MonthSection) -> some View {
        HStack {
            Text(section.title)
                .font(.headline)
            Spacer()
            if isSelecting {
                let ids = section.assetIDs
                let allSelected = ids.allSatisfy { selection.contains($0) }
                Button(allSelected ? "Deselect" : "Select All") {
                    if allSelected {
                        selection.subtract(ids)
                    } else {
                        selection.formUnion(ids)
                    }
                }
                .font(.subheadline)
            } else {
                Text(section.assets.count.formatted())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !library.sections.isEmpty {
                Button(isSelecting ? "Done" : "Select") {
                    if isSelecting { endSelection() } else { isSelecting = true }
                }
            }
        }
    }

    private var selectedAssets: [PHAsset] {
        library.allAssets.filter { selection.contains($0.localIdentifier) }
    }

    private func tap(_ asset: PHAsset) {
        if isSelecting {
            if selection.contains(asset.localIdentifier) {
                selection.remove(asset.localIdentifier)
            } else {
                selection.insert(asset.localIdentifier)
            }
        } else {
            viewer = ViewerRoute(assets: library.allAssets, startID: asset.localIdentifier)
        }
    }

    private func endSelection() {
        isSelecting = false
        selection.removeAll()
    }

    private func favoriteSelection() async {
        let assets = selectedAssets
        guard !assets.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        // If every selected item is already a favorite, the action removes them instead.
        let makeFavorite = !assets.allSatisfy(\.isFavorite)
        do {
            try await library.setFavorite(assets, to: makeFavorite)
            endSelection()
        } catch {
            alert = AlertMessage("Couldn't Update Favorites", error)
        }
    }

    private func deleteSelection() async {
        let assets = selectedAssets
        guard !assets.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            if try await library.delete(assets) {
                endSelection()
            }
        } catch {
            alert = AlertMessage("Couldn't Delete", error)
        }
    }
}

struct LimitedAccessBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.badge.checkmark")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text("Tidyroll can only see the photos you chose.")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Manage") {
                SystemActions.presentLimitedLibraryPicker()
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SelectionActionBar: View {
    let count: Int
    let isWorking: Bool
    var onAddToAlbum: () -> Void
    var onFavorite: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onAddToAlbum) {
                Label("Add to Album", systemImage: "rectangle.stack.badge.plus")
            }
            Spacer()
            Button(action: onFavorite) {
                Label("Favorite", systemImage: "heart")
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .overlay {
            if isWorking {
                ProgressView()
            } else {
                Text(count == 0 ? "Select Items" : count.counted("Item") + " Selected")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .disabled(count == 0 || isWorking)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

/// Identifiable list of assets for `.sheet(item:)`.
struct AssetBatch: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
}

struct ViewerRoute: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    let startID: String
}
