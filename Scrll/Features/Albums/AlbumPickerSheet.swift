import Photos
import SwiftUI

/// Adds the given assets to an existing album or a new one.
struct AlbumPickerSheet: View {
    let assets: [PHAsset]
    var onDone: () -> Void

    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var isNamingNewAlbum = false
    @State private var newAlbumTitle = ""
    @State private var isWorking = false
    @State private var alert: AlertMessage?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        newAlbumTitle = ""
                        isNamingNewAlbum = true
                    } label: {
                        Label("New Album…", systemImage: "plus.rectangle.on.rectangle")
                    }
                }
                if !library.albums.isEmpty {
                    Section("My Albums") {
                        ForEach(library.albums) { album in
                            Button {
                                Task { await add(to: album) }
                            } label: {
                                AlbumRow(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .disabled(isWorking)
            .overlay { if isWorking { ProgressView() } }
            .navigationTitle("Add \(assets.count.counted("Item"))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Album", isPresented: $isNamingNewAlbum) {
                TextField("Album name", text: $newAlbumTitle)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    Task { await createAlbum() }
                }
            } message: {
                Text("Enter a name for the album.")
            }
            .errorAlert($alert)
        }
    }

    private func add(to album: AlbumInfo) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await library.add(assets, to: album.collection)
            finish()
        } catch {
            alert = AlertMessage("Couldn't Add to Album", error)
        }
    }

    private func createAlbum() async {
        let title = newAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await library.createAlbum(named: title, with: assets)
            finish()
        } catch {
            alert = AlertMessage("Couldn't Create Album", error)
        }
    }

    private func finish() {
        onDone()
        dismiss()
    }
}

struct AlbumRow: View {
    let album: AlbumInfo

    var body: some View {
        HStack(spacing: 12) {
            AlbumCover(album: album)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.body)
                    .lineLimit(1)
                Text(album.count.counted("item"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct AlbumCover: View {
    let album: AlbumInfo

    var body: some View {
        if let cover = album.cover {
            AssetThumbnail(asset: cover, pointSize: 200, showsBadges: false)
        } else {
            Rectangle()
                .fill(Color(.secondarySystemFill))
                .overlay {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
