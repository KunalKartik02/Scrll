import AVFoundation
import Photos
import UIKit

/// Thin async wrapper around `PHCachingImageManager`.
final class ImageLoader {
    static let shared = ImageLoader()

    private let manager = PHCachingImageManager()

    private init() {
        manager.allowsCachingHighQualityImages = false
    }

    /// Streams progressively better images for an asset: first a quick low-quality
    /// version, then the final one. Cancelling the consuming task cancels the request.
    func images(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill
    ) -> AsyncStream<UIImage> {
        AsyncStream { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true

            let requestID = self.manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                if let image {
                    continuation.yield(image)
                }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let failed = info?[PHImageErrorKey] != nil
                if !isDegraded || isCancelled || failed {
                    continuation.finish()
                }
            }

            let imageManager = self.manager
            continuation.onTermination = { _ in
                imageManager.cancelImageRequest(requestID)
            }
        }
    }

    /// One full-quality image, suitable for sharing.
    func fullImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            let gate = ResumeGate()
            manager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                guard gate.claim() else { return }
                continuation.resume(returning: image)
            }
        }
    }

    /// A tiny local-only image used for duplicate detection. Never downloads from iCloud.
    func hashingImage(for asset: PHAsset) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            let gate = ResumeGate()
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 64, height: 64),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard gate.claim() else { return }
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    func playerItem(for asset: PHAsset) async -> AVPlayerItem? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            let gate = ResumeGate()
            manager.requestPlayerItem(forVideo: asset, options: options) { item, _ in
                guard gate.claim() else { return }
                continuation.resume(returning: item)
            }
        }
    }

    /// A file URL for a video, suitable for sharing.
    func videoURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .current
            let gate = ResumeGate()
            manager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                guard gate.claim() else { return }
                continuation.resume(returning: (avAsset as? AVURLAsset)?.url)
            }
        }
    }
}

/// Makes sure a continuation is resumed exactly once even if PhotoKit calls back twice.
private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
