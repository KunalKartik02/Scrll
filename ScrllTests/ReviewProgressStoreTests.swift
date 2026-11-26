import XCTest
@testable import Scrll

@MainActor
final class ReviewProgressStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() async throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("progress.json")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    func testMarkAndPersist() {
        let store = ReviewProgressStore(fileURL: fileURL)
        XCTAssertTrue(store.reviewed.isEmpty)
        store.markReviewed(["a", "b"])
        XCTAssertTrue(store.isReviewed("a"))
        XCTAssertEqual(store.reviewedCount(in: ["a", "b", "c"]), 2)

        let reloaded = ReviewProgressStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.reviewed, ["a", "b"])
    }

    func testUnmarkAndReset() {
        let store = ReviewProgressStore(fileURL: fileURL)
        store.markReviewed(["a", "b", "c"])
        store.unmark(["b"])
        XCTAssertEqual(ReviewProgressStore(fileURL: fileURL).reviewed, ["a", "c"])

        store.reset()
        XCTAssertTrue(ReviewProgressStore(fileURL: fileURL).reviewed.isEmpty)
    }

    func testCorruptFileIsIgnored() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: fileURL)
        XCTAssertTrue(ReviewProgressStore(fileURL: fileURL).reviewed.isEmpty)
    }
}
