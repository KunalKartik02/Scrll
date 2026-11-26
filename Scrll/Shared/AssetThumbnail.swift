import Photos
import SwiftUI

/// Square-friendly thumbnail that fills its frame. Wrap it in a sized container.
struct AssetThumbnail: View {
    let asset: PHAsset
    var pointSize: CGFloat = 130
    var showsBadges = true

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Rectangle()
            .fill(Color(.secondarySystemFill))
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottom) {
                if showsBadges {
                    AssetBadges(asset: asset)
                }
            }
            .task(id: asset.localIdentifier) {
                image = nil
                let side = pointSize * displayScale
                let stream = ImageLoader.shared.images(
                    for: asset,
                    targetSize: CGSize(width: side, height: side),
                    contentMode: .aspectFill
                )
                for await next in stream {
                    image = next
                }
            }
            .accessibilityElement()
            .accessibilityLabel(asset.accessibilityDescription)
    }
}

/// Fits the whole asset inside its frame (used for full-screen and review cards).
struct AssetImage: View {
    let asset: PHAsset
    var maxPixelSide: CGFloat = 2048

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: asset.localIdentifier) {
            image = nil
            let stream = ImageLoader.shared.images(
                for: asset,
                targetSize: CGSize(width: maxPixelSide, height: maxPixelSide),
                contentMode: .aspectFit
            )
            for await next in stream {
                image = next
            }
        }
        .accessibilityElement()
        .accessibilityLabel(asset.accessibilityDescription)
    }
}

struct AssetBadges: View {
    let asset: PHAsset

    var body: some View {
        HStack(spacing: 4) {
            if asset.isFavorite {
                Image(systemName: "heart.fill")
            }
            Spacer(minLength: 0)
            if asset.mediaType == .video {
                Text(asset.duration.clockString)
                    .monospacedDigit()
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 2)
        .padding(5)
    }
}

/// A square grid cell with an optional selection checkmark.
struct GridCell: View {
    let asset: PHAsset
    var isSelecting = false
    var isSelected = false
    var isDimmed = false

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { AssetThumbnail(asset: asset) }
            .clipped()
            .overlay {
                if isDimmed || (isSelecting && isSelected) {
                    Color.black.opacity(isDimmed ? 0.45 : 0.2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelecting {
                    SelectionMark(isSelected: isSelected)
                        .padding(5)
                }
            }
            .contentShape(Rectangle())
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SelectionMark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.black.opacity(0.25))
            Circle()
                .strokeBorder(.white, lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
    }
}

struct SectionHeaderView: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
