import Photos
import SwiftUI

/// Shows what a review pass will delete and lets the person rescue photos before confirming.
struct ReviewSummaryView: View {
    @ObservedObject var model: ReviewViewModel
    var onKeepReviewing: () -> Void
    var onFinish: () -> Void

    @EnvironmentObject private var library: PhotoLibrary
    @EnvironmentObject private var progress: ReviewProgressStore
    @State private var isDeleting = false
    @State private var showingDiscardConfirm = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 2)]

    var body: some View {
        let trashed = model.trashedAssets
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text(trashed.isEmpty
                     ? "Nothing is marked for deletion."
                     : "\(trashed.count.counted("item")) will be deleted")
                    .font(.title3.bold())
                Text("Tap a photo to keep it instead. Deleted items go to Recently Deleted for 30 days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(model.decidedAssets, id: \.localIdentifier) { asset in
                    let isTrashed = model.decision(for: asset) == .trash
                    Button {
                        model.toggleTrash(asset, library: library, progress: progress)
                    } label: {
                        GridCell(asset: asset, isDimmed: !isTrashed)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: isTrashed ? "trash.circle.fill" : "checkmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, isTrashed ? Color.red : Color.green)
                                    .padding(5)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(asset.accessibilityDescription)
                    .accessibilityValue(isTrashed ? "Will be deleted" : "Will be kept")
                    .accessibilityHint("Double tap to change")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(role: .destructive) {
                    Task { await deleteAndFinish() }
                } label: {
                    Group {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text(trashed.isEmpty ? "Done" : "Delete \(trashed.count.counted("Item"))")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(trashed.isEmpty ? Color.accentColor : Color.red)
                .controlSize(.large)
                .disabled(isDeleting)

                HStack {
                    if !model.session.isComplete {
                        Button("Keep Reviewing", action: onKeepReviewing)
                    }
                    Spacer()
                    if !trashed.isEmpty {
                        Button("Discard & Close", role: .destructive) {
                            showingDiscardConfirm = true
                        }
                    }
                }
                .font(.subheadline)
                .disabled(isDeleting)
            }
            .padding()
            .background(.bar)
        }
        .confirmationDialog(
            "Close without deleting?",
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Close Without Deleting", role: .destructive, action: onFinish)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Photos marked for deletion will stay in your library and remain unreviewed.")
        }
    }

    private func deleteAndFinish() async {
        isDeleting = true
        let done = await model.commitDeletions(library: library)
        isDeleting = false
        if done {
            onFinish()
        }
    }
}
