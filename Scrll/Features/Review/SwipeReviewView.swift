import Photos
import SwiftUI

struct SwipeReviewView: View {
    let title: String

    @EnvironmentObject private var library: PhotoLibrary
    @EnvironmentObject private var progress: ReviewProgressStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var model: ReviewViewModel
    @State private var offset: CGSize = .zero
    @State private var isAnimatingOut = false
    @State private var showingSummary = false

    private let swipeThreshold: CGFloat = 110

    init(title: String, assets: [PHAsset]) {
        self.title = title
        _model = StateObject(wrappedValue: ReviewViewModel(assets: assets))
    }

    var body: some View {
        NavigationStack {
            Group {
                if showingSummary {
                    ReviewSummaryView(model: model) {
                        showingSummary = false
                    } onFinish: {
                        dismiss()
                    }
                } else {
                    reviewBody
                }
            }
            .navigationTitle(showingSummary ? "Summary" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !showingSummary {
                        Button("Close") { close() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !showingSummary && model.session.reviewedCount > 0 {
                        Button("Finish") { close() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .errorAlert($model.lastError)
        }
        .interactiveDismissDisabled(!model.trashedAssets.isEmpty)
    }

    // MARK: - Swiping

    private var reviewBody: some View {
        VStack(spacing: 16) {
            ProgressView(value: model.session.progress)
                .padding(.horizontal)
            Text("\(min(model.session.reviewedCount + 1, model.session.total)) of \(model.session.total)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            ZStack {
                if let next = model.nextAsset {
                    ReviewCard(asset: next)
                        .scaleEffect(0.94)
                        .opacity(0.7)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if let current = model.currentAsset {
                    ReviewCard(asset: current)
                        .overlay { stamps }
                        .offset(offset)
                        .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset.width / 22)))
                        .gesture(dragGesture)
                        .id(current.localIdentifier)
                        .accessibilityAction(named: "Keep") { fling(.keep) }
                        .accessibilityAction(named: "Delete") { fling(.trash) }
                        .accessibilityAction(named: "Favorite") { fling(.favorite) }
                } else {
                    completion
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)

            controls
                .padding(.bottom, 12)
        }
        .padding(.top, 8)
    }

    private var stamps: some View {
        ZStack {
            Stamp(text: "KEEP", color: .green)
                .opacity(Double(max(0, offset.width) / swipeThreshold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Stamp(text: "DELETE", color: .red)
                .opacity(Double(max(0, -offset.width) / swipeThreshold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            Stamp(text: "FAVORITE", color: .pink)
                .opacity(Double(max(0, -offset.height) / swipeThreshold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(24)
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isAnimatingOut else { return }
                offset = value.translation
            }
            .onEnded { value in
                guard !isAnimatingOut else { return }
                let t = value.translation
                if t.width > swipeThreshold && abs(t.width) >= abs(t.height) {
                    fling(.keep)
                } else if t.width < -swipeThreshold && abs(t.width) >= abs(t.height) {
                    fling(.trash)
                } else if t.height < -swipeThreshold {
                    fling(.favorite)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                }
            }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            RoundActionButton(symbol: "trash", color: .red, label: "Delete") { fling(.trash) }
            RoundActionButton(symbol: "arrow.uturn.backward", color: .secondary, label: "Undo", small: true) {
                guard !isAnimatingOut else { return }
                model.undo(library: library, progress: progress)
            }
            .disabled(!model.session.canUndo)
            RoundActionButton(symbol: "heart.fill", color: .pink, label: "Favorite", small: true) { fling(.favorite) }
            RoundActionButton(symbol: "checkmark", color: .green, label: "Keep") { fling(.keep) }
        }
        .disabled(isAnimatingOut)
    }

    private var completion: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("All Done")
                .font(.title2.bold())
            Text(model.trashedAssets.isEmpty
                 ? "You kept everything in this set."
                 : "\(model.trashedAssets.count.counted("item")) marked for deletion.")
                .foregroundStyle(.secondary)
            Button(model.trashedAssets.isEmpty ? "Done" : "Review & Delete") {
                close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .multilineTextAlignment(.center)
    }

    private func fling(_ decision: ReviewDecision) {
        guard !isAnimatingOut, model.currentAsset != nil else { return }
        isAnimatingOut = true
        let target: CGSize
        switch decision {
        case .keep: target = CGSize(width: 700, height: offset.height)
        case .trash: target = CGSize(width: -700, height: offset.height)
        case .favorite: target = CGSize(width: offset.width, height: -1000)
        }
        withAnimation(.easeIn(duration: 0.2)) {
            offset = target
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                model.decide(decision, library: library, progress: progress)
                offset = .zero
            }
            isAnimatingOut = false
        }
    }

    private func close() {
        if model.trashedAssets.isEmpty {
            dismiss()
        } else {
            showingSummary = true
        }
    }
}

private struct ReviewCard: View {
    let asset: PHAsset

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                AssetImage(asset: asset, maxPixelSide: 1600)
                    .padding(10)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    if let date = asset.creationDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                    }
                    if asset.mediaType == .video {
                        Label(asset.duration.clockString, systemImage: "video.fill")
                    }
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(18)
            }
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

private struct Stamp: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.title.weight(.heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 4))
            .background(Color(.systemBackground).opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RoundActionButton: View {
    let symbol: String
    let color: Color
    let label: String
    var small = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(small ? .title3.weight(.semibold) : .title.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: small ? 52 : 68, height: small ? 52 : 68)
                .background(Color(.secondarySystemBackground), in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
