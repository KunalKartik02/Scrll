import Photos
import SwiftUI

struct DuplicatesView: View {
    @ObservedObject var scanner: DuplicateScanner

    @EnvironmentObject private var library: PhotoLibrary
    @State private var alert: AlertMessage?
    @State private var isDeleting = false

    var body: some View {
        Group {
            switch scanner.phase {
            case .idle:
                ContentUnavailableView {
                    Label("Find Duplicates", systemImage: "square.on.square")
                } description: {
                    Text("Tidyroll compares your photos on this iPhone to find copies that look the same. Photos stored only in iCloud are skipped.")
                } actions: {
                    Button("Start Scan") { scanner.start(using: library) }
                        .buttonStyle(.borderedProminent)
                }
            case let .scanning(done, total):
                VStack(spacing: 16) {
                    ProgressView(value: Double(done), total: Double(max(total, 1)))
                    Text("Scanning \(done.formatted()) of \(total.formatted()) photos…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Cancel", role: .cancel) { scanner.cancel() }
                }
                .padding(32)
            case .finished:
                if scanner.groups.isEmpty {
                    ContentUnavailableView {
                        Label("No Duplicates", systemImage: "checkmark.circle")
                    } description: {
                        Text("Your library has no matching photos.")
                    } actions: {
                        Button("Scan Again") { scanner.start(using: library) }
                    }
                } else {
                    results
                }
            }
        }
        .navigationTitle("Duplicates")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert($alert)
    }

    private var results: some View {
        List {
            Section {
                Text("The copy marked Keep is the sharpest version. Tap a photo to change what you keep.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach($scanner.groups) { $group in
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(group.assets, id: \.localIdentifier) { asset in
                                let keep = group.keep.contains(asset.localIdentifier)
                                Button {
                                    group.toggleKeep(asset.localIdentifier)
                                } label: {
                                    AssetThumbnail(asset: asset, pointSize: 120)
                                        .frame(width: 110, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(keep ? Color.green : Color.clear, lineWidth: 3)
                                        }
                                        .overlay(alignment: .bottom) {
                                            Text(keep ? "Keep" : "Delete")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(keep ? Color.green : Color.red, in: Capsule())
                                                .padding(6)
                                        }
                                        .opacity(keep ? 1 : 0.75)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(asset.accessibilityDescription)
                                .accessibilityValue(keep ? "Keep" : "Delete")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(group.assets.count.counted("copy", "copies"))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                Task { await deleteDuplicates() }
            } label: {
                Group {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("Delete \(scanner.deletableCount.counted("Duplicate"))")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(scanner.deletableCount == 0 || isDeleting)
            .padding()
            .background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rescan") { scanner.start(using: library) }
                    .disabled(isDeleting)
            }
        }
    }

    private func deleteDuplicates() async {
        let toDelete = scanner.groups.flatMap(\.assetsToDelete)
        guard !toDelete.isEmpty else { return }
        isDeleting = true
        defer { isDeleting = false }
        do {
            if try await library.delete(toDelete) {
                scanner.removeDeleted(Set(toDelete.map(\.localIdentifier)))
            }
        } catch {
            alert = AlertMessage("Couldn't Delete Duplicates", error)
        }
    }
}
