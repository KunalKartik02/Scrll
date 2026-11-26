import Photos
import SwiftUI

struct AlbumsView: View {
    @EnvironmentObject private var library: PhotoLibrary

    @State private var isNamingNewAlbum = false
    @State private var newAlbumTitle = ""
    @State private var renaming: AlbumInfo?
    @State private var renameTitle = ""
    @State private var deleting: AlbumInfo?
    @State private var alert: AlertMessage?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if library.albums.isEmpty {
                    ContentUnavailableView {
                        Label("No Albums Yet", systemImage: "square.stack")
                    } description: {
                        Text("Create an album, then add photos from your Library or while reviewing.")
                    } actions: {
                        Button("New Album") { startNewAlbum() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(library.albums) { album in
                                NavigationLink(value: album.id) {
                                    AlbumTile(album: album)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        renameTitle = album.title
                                        renaming = album
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        deleting = album
                                    } label: {
                                        Label("Delete Album", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Albums")
            .navigationDestination(for: String.self) { albumID in
                AlbumDetailView(albumID: albumID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewAlbum()
                    } label: {
                        Label("New Album", systemImage: "plus")
                    }
                }
            }
            .alert("New Album", isPresented: $isNamingNewAlbum) {
                TextField("Album name", text: $newAlbumTitle)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let title = newAlbumTitle
                    Task { await run("Couldn't Create Album") { try await library.createAlbum(named: title) } }
                }
            }
            .alert("Rename Album", isPresented: isPresent($renaming)) {
                TextField("Album name", text: $renameTitle)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Rename") {
                    guard let album = renaming else { return }
                    let title = renameTitle
                    renaming = nil
                    Task { await run("Couldn't Rename Album") { try await library.rename(album.collection, to: title) } }
                }
            }
            .confirmationDialog(
                "Delete “\(deleting?.title ?? "")”?",
                isPresented: isPresent($deleting),
                titleVisibility: .visible
            ) {
                Button("Delete Album", role: .destructive) {
                    guard let album = deleting else { return }
                    deleting = nil
                    Task { await run("Couldn't Delete Album") { try await library.deleteAlbum(album.collection) } }
                }
                Button("Cancel", role: .cancel) { deleting = nil }
            } message: {
                Text("The photos stay in your library.")
            }
            .errorAlert($alert)
        }
    }

    private func startNewAlbum() {
        newAlbumTitle = ""
        isNamingNewAlbum = true
    }

    private func run(_ failureTitle: String, _ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            alert = AlertMessage(failureTitle, error)
        }
    }

    private func isPresent(_ binding: Binding<AlbumInfo?>) -> Binding<Bool> {
        Binding(
            get: { binding.wrappedValue != nil },
            set: { if !$0 { binding.wrappedValue = nil } }
        )
    }
}

private struct AlbumTile: View {
    let album: AlbumInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { AlbumCover(album: album) }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(album.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(album.count.formatted())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
