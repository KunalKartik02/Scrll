import AVKit
import Photos
import SwiftUI

/// Full-screen, swipeable viewer with share, favorite, add-to-album and delete.
struct PhotoViewer: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PHAsset]
    @State private var currentID: String?
    @State private var favoriteOverrides: [String: Bool] = [:]
    @State private var share: ShareItems?
    @State private var albumPickerAssets: AssetBatch?
    @State private var alert: AlertMessage?
    @State private var isWorking = false

    init(assets: [PHAsset], startID: String) {
        _items = State(initialValue: assets)
        _currentID = State(initialValue: startID)
    }

    private var current: PHAsset? {
        guard let currentID else { return nil }
        return items.first { $0.localIdentifier == currentID }
    }

    private var isCurrentFavorite: Bool {
        guard let current else { return false }
        return favoriteOverrides[current.localIdentifier] ?? current.isFavorite
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(items, id: \.localIdentifier) { asset in
                            ViewerPage(asset: asset, isCurrent: asset.localIdentifier == currentID)
                                .containerRelativeFrame([.horizontal, .vertical])
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentID)
                .scrollIndicators(.hidden)
                .onAppear {
                    if let currentID {
                        proxy.scrollTo(currentID)
                    }
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .toolbarBackground(.visible, for: .navigationBar, .bottomBar)
            .sheet(item: $share) { item in
                ShareSheet(items: item.items)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $albumPickerAssets) { batch in
                AlbumPickerSheet(assets: batch.assets) {}
                    .environmentObject(library)
            }
            .errorAlert($alert)
        }
        .environment(\.colorScheme, .dark)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                if let date = current?.creationDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                Task { await shareCurrent() }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Spacer()
            Button {
                Task { await toggleFavorite() }
            } label: {
                Label(isCurrentFavorite ? "Unfavorite" : "Favorite",
                      systemImage: isCurrentFavorite ? "heart.fill" : "heart")
            }
            Spacer()
            Button {
                if let current { albumPickerAssets = AssetBatch(assets: [current]) }
            } label: {
                Label("Add to Album", systemImage: "rectangle.stack.badge.plus")
            }
            Spacer()
            Button(role: .destructive) {
                Task { await deleteCurrent() }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func shareCurrent() async {
        guard let asset = current, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if asset.mediaType == .video {
            if let url = await ImageLoader.shared.videoURL(for: asset) {
                share = ShareItems(items: [url])
            } else {
                alert = AlertMessage(title: "Can't Share Video", message: "The video couldn't be loaded.")
            }
        } else if let image = await ImageLoader.shared.fullImage(for: asset) {
            share = ShareItems(items: [image])
        } else {
            alert = AlertMessage(title: "Can't Share Photo", message: "The photo couldn't be loaded.")
        }
    }

    private func toggleFavorite() async {
        guard let asset = current else { return }
        let newValue = !isCurrentFavorite
        do {
            try await library.setFavorite([asset], to: newValue)
            favoriteOverrides[asset.localIdentifier] = newValue
        } catch {
            alert = AlertMessage("Couldn't Update Favorite", error)
        }
    }

    private func deleteCurrent() async {
        guard let asset = current, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            guard try await library.delete([asset]) else { return }
            guard let index = items.firstIndex(of: asset) else { return }
            items.remove(at: index)
            if items.isEmpty {
                dismiss()
            } else {
                currentID = items[min(index, items.count - 1)].localIdentifier
            }
        } catch {
            alert = AlertMessage("Couldn't Delete", error)
        }
    }
}

private struct ViewerPage: View {
    let asset: PHAsset
    let isCurrent: Bool

    @State private var player: AVPlayer?
    @State private var isLoadingVideo = false

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            } else {
                AssetImage(asset: asset)
                    .tint(.white)
                if asset.mediaType == .video {
                    Button {
                        Task { await play() }
                    } label: {
                        Group {
                            if isLoadingVideo {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 64))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.4))
                            }
                        }
                    }
                    .accessibilityLabel("Play video")
                }
            }
        }
        .onChange(of: isCurrent) { _, nowCurrent in
            if !nowCurrent { stop() }
        }
        .onDisappear { stop() }
    }

    private func play() async {
        guard !isLoadingVideo else { return }
        isLoadingVideo = true
        defer { isLoadingVideo = false }
        guard let item = await ImageLoader.shared.playerItem(for: asset) else { return }
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        newPlayer.play()
    }

    private func stop() {
        player?.pause()
        player = nil
    }
}
