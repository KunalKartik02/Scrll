import XCTest
@testable import Scrll

final class DuplicateGrouperTests: XCTestCase {
    private func item(_ id: String, _ hash: UInt64, aspect: Double = 1.5) -> DuplicateGrouper.Item {
        .init(id: id, hash: hash, aspectRatio: aspect)
    }

    func testGroupsNearIdenticalHashes() {
        let items = [
            item("a", 0b0000),
            item("b", 0b0001),
            item("c", 0xFFFF_0000_FFFF_0000),
            item("d", 0b0011),
        ]
        XCTAssertEqual(DuplicateGrouper.groups(items), [["a", "b", "d"]])
    }

    func testSingletonsAreNotReported() {
        let items = [item("a", 0), item("b", UInt64.max)]
        XCTAssertTrue(DuplicateGrouper.groups(items).isEmpty)
    }

    func testEmptyAndSingleInput() {
        XCTAssertTrue(DuplicateGrouper.groups([]).isEmpty)
        XCTAssertTrue(DuplicateGrouper.groups([item("a", 0)]).isEmpty)
    }

    func testDifferentShapesAreNotDuplicates() {
        let items = [item("wide", 0, aspect: 16.0 / 9.0), item("square", 0, aspect: 1)]
        XCTAssertTrue(DuplicateGrouper.groups(items).isEmpty)
    }

    func testSmallAspectDifferencesAreTolerated() {
        let items = [item("a", 0, aspect: 1.50), item("b", 0, aspect: 1.52)]
        XCTAssertEqual(DuplicateGrouper.groups(items), [["a", "b"]])
    }

    func testGroupsAreTransitive() {
        // a~b (2 bits) and b~c (2 bits), but a and c differ by 4 bits, beyond the threshold of 2.
        let items = [item("a", 0b0000_0000), item("b", 0b0000_0011), item("c", 0b0000_1111)]
        XCTAssertEqual(DuplicateGrouper.groups(items, threshold: 2), [["a", "b", "c"]])
    }

    func testSeparateGroupsKeepInputOrder() {
        let items = [
            item("x1", UInt64.max),
            item("a1", 0),
            item("x2", UInt64.max),
            item("a2", 1),
        ]
        XCTAssertEqual(DuplicateGrouper.groups(items), [["x1", "x2"], ["a1", "a2"]])
    }

    func testPreferredIndexPicksHighestResolution() {
        let candidates = [
            DuplicateGrouper.Candidate(pixelCount: 100, isFavorite: true, creationDate: nil),
            DuplicateGrouper.Candidate(pixelCount: 400, isFavorite: false, creationDate: nil),
        ]
        XCTAssertEqual(DuplicateGrouper.preferredIndex(candidates), 1)
    }

    func testPreferredIndexBreaksTiesWithFavoriteThenOldest() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let favoriteWins = [
            DuplicateGrouper.Candidate(pixelCount: 100, isFavorite: false, creationDate: older),
            DuplicateGrouper.Candidate(pixelCount: 100, isFavorite: true, creationDate: newer),
        ]
        XCTAssertEqual(DuplicateGrouper.preferredIndex(favoriteWins), 1)

        let oldestWins = [
            DuplicateGrouper.Candidate(pixelCount: 100, isFavorite: false, creationDate: newer),
            DuplicateGrouper.Candidate(pixelCount: 100, isFavorite: false, creationDate: older),
        ]
        XCTAssertEqual(DuplicateGrouper.preferredIndex(oldestWins), 1)
    }

    func testPreferredIndexOfEmptyIsNil() {
        XCTAssertNil(DuplicateGrouper.preferredIndex([]))
    }
}
