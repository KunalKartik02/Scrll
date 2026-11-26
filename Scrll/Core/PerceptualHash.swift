import CoreGraphics

/// Difference hash ("dHash") used to find visually identical or near-identical photos.
///
/// The image is reduced to a 9×8 grayscale grid; each bit records whether a pixel is
/// darker than its right-hand neighbour. Two photos whose hashes differ in only a few
/// bits look the same to a person, even after re-compression or small resizes.
enum PerceptualHash {
    static let gridWidth = 9
    static let gridHeight = 8

    /// Computes the dHash of an image. Returns `nil` if a drawing context cannot be created.
    static func dHash(_ image: CGImage) -> UInt64? {
        var pixels = [UInt8](repeating: 0, count: gridWidth * gridHeight)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: gridWidth,
                height: gridHeight,
                bitsPerComponent: 8,
                bytesPerRow: gridWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: gridWidth, height: gridHeight))
            return true
        }
        guard drawn else { return nil }
        return hash(grayscale: pixels)
    }

    /// Computes the hash from a row-major 9×8 grayscale buffer.
    static func hash(grayscale pixels: [UInt8]) -> UInt64 {
        precondition(pixels.count == gridWidth * gridHeight, "Expected a 9x8 grayscale buffer")
        var result: UInt64 = 0
        var bit: UInt64 = 0
        for row in 0..<gridHeight {
            for column in 0..<(gridWidth - 1) {
                let left = pixels[row * gridWidth + column]
                let right = pixels[row * gridWidth + column + 1]
                if left < right {
                    result |= (UInt64(1) << bit)
                }
                bit += 1
            }
        }
        return result
    }

    /// Number of differing bits between two hashes (0 = identical, 64 = opposite).
    static func distance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }
}
