import CoreGraphics
import XCTest
@testable import Scrll

final class PerceptualHashTests: XCTestCase {
    func testIncreasingRowsSetEveryBit() {
        let pixels = (0..<8).flatMap { _ in (0..<9).map { UInt8($0 * 20) } }
        XCTAssertEqual(PerceptualHash.hash(grayscale: pixels), UInt64.max)
    }

    func testFlatImageHasNoBits() {
        let pixels = [UInt8](repeating: 128, count: 72)
        XCTAssertEqual(PerceptualHash.hash(grayscale: pixels), 0)
    }

    func testDecreasingRowsHaveNoBits() {
        let pixels = (0..<8).flatMap { _ in (0..<9).map { UInt8(200 - $0 * 20) } }
        XCTAssertEqual(PerceptualHash.hash(grayscale: pixels), 0)
    }

    func testFirstBitTracksTopLeftPair() {
        var pixels = [UInt8](repeating: 100, count: 72)
        pixels[1] = 101
        XCTAssertEqual(PerceptualHash.hash(grayscale: pixels), 1)
    }

    func testDistance() {
        XCTAssertEqual(PerceptualHash.distance(0, 0), 0)
        XCTAssertEqual(PerceptualHash.distance(0, UInt64.max), 64)
        XCTAssertEqual(PerceptualHash.distance(0b1011, 0b0001), 2)
    }

    func testSameImageAtDifferentSizesMatches() throws {
        let small = try XCTUnwrap(makeGradientImage(width: 64, height: 48))
        let large = try XCTUnwrap(makeGradientImage(width: 640, height: 480))
        let a = try XCTUnwrap(PerceptualHash.dHash(small))
        let b = try XCTUnwrap(PerceptualHash.dHash(large))
        XCTAssertLessThanOrEqual(PerceptualHash.distance(a, b), DuplicateGrouper.defaultThreshold)
    }

    func testDifferentImagesDiffer() throws {
        let forward = try XCTUnwrap(makeGradientImage(width: 90, height: 80, reversed: false))
        let backward = try XCTUnwrap(makeGradientImage(width: 90, height: 80, reversed: true))
        let a = try XCTUnwrap(PerceptualHash.dHash(forward))
        let b = try XCTUnwrap(PerceptualHash.dHash(backward))
        XCTAssertGreaterThan(PerceptualHash.distance(a, b), 32)
    }

    /// Horizontal grayscale gradient, drawn into a context that owns its memory.
    private func makeGradientImage(width: Int, height: Int, reversed: Bool = false) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let data = context.data else {
            return nil
        }
        let rowBytes = context.bytesPerRow
        let buffer = data.bindMemory(to: UInt8.self, capacity: rowBytes * height)
        for y in 0..<height {
            for x in 0..<width {
                let value = Double(x) / Double(max(width - 1, 1)) * 255
                buffer[y * rowBytes + x] = UInt8(reversed ? 255 - value : value)
            }
        }
        return context.makeImage()
    }
}
