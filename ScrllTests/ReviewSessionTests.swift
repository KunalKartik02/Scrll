import XCTest
@testable import Scrll

final class ReviewSessionTests: XCTestCase {
    func testDecideAdvancesThroughPhotos() {
        var session = ReviewSession(ids: ["a", "b", "c"])
        XCTAssertEqual(session.current, "a")
        XCTAssertEqual(session.next, "b")

        session.decide(.keep)
        XCTAssertEqual(session.current, "b")
        session.decide(.trash)
        session.decide(.favorite)

        XCTAssertNil(session.current)
        XCTAssertNil(session.next)
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.progress, 1)
        XCTAssertNil(session.decide(.keep), "Deciding past the end does nothing")
        XCTAssertEqual(session.reviewedCount, 3)
    }

    func testUndoRestoresPreviousPhoto() {
        var session = ReviewSession(ids: ["a", "b"])
        session.decide(.trash)
        XCTAssertEqual(session.undo(), .init(id: "a", decision: .trash))
        XCTAssertEqual(session.current, "a")
        XCTAssertFalse(session.canUndo)
        XCTAssertNil(session.undo())
    }

    func testDuplicatesAreRemovedPreservingOrder() {
        let session = ReviewSession(ids: ["a", "b", "a", "c", "b"])
        XCTAssertEqual(session.ids, ["a", "b", "c"])
    }

    func testSetDecisionChangesEarlierChoice() {
        var session = ReviewSession(ids: ["a", "b"])
        session.decide(.trash)
        session.decide(.trash)
        session.setDecision(.keep, for: "a")
        XCTAssertEqual(session.ids(withDecision: .trash), ["b"])
        XCTAssertEqual(session.ids(withDecision: .keep), ["a"])
        XCTAssertEqual(session.decision(for: "a"), .keep)
        XCTAssertNil(session.decision(for: "zzz"))
    }

    func testRemoveDecisions() {
        var session = ReviewSession(ids: ["a", "b", "c"])
        session.decide(.trash)
        session.decide(.keep)
        session.removeDecisions(for: ["a"])
        XCTAssertEqual(session.history.map(\.id), ["b"])
    }

    func testEmptySessionIsComplete() {
        let session = ReviewSession(ids: [])
        XCTAssertTrue(session.isComplete)
        XCTAssertNil(session.current)
        XCTAssertEqual(session.progress, 1)
    }

    func testProgress() {
        var session = ReviewSession(ids: ["a", "b", "c", "d"])
        session.decide(.keep)
        XCTAssertEqual(session.progress, 0.25, accuracy: 0.0001)
    }
}
