import XCTest

/// End-to-end walk through every screen against real sample photos in the simulator.
/// CI adds the photos from `ci/sample-photos` (six photos plus a near-identical copy of one).
/// Screenshots are kept as test attachments so the run can be checked visually.
final class ScrllUITests: XCTestCase {
    private var app: XCUIApplication!
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        grantPhotoAccessIfAsked()
    }

    @MainActor
    func testEndToEnd() throws {
        // Library
        let libraryTab = app.tabBars.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 30), "Main tabs should appear after access is granted")
        let firstPhoto = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 30), "Sample photos should load in the Library")
        capture("01-Library")

        // Viewer
        firstPhoto.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        pause(2)
        capture("02-Viewer")
        done.tap()
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10))

        // Clean Up → Duplicates (before Review deletes anything)
        app.tabBars.buttons["Clean Up"].tap()
        let duplicatesRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Duplicates'")).firstMatch
        XCTAssertTrue(duplicatesRow.waitForExistence(timeout: 10))
        capture("03-CleanUp")
        duplicatesRow.tap()
        let startScan = app.buttons["Start Scan"]
        XCTAssertTrue(startScan.waitForExistence(timeout: 10))
        startScan.tap()
        let deleteDuplicates = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete 1 Duplicate'")).firstMatch
        XCTAssertTrue(deleteDuplicates.waitForExistence(timeout: 90), "The copied sample photo should be found as a duplicate")
        capture("04-Duplicates")
        app.navigationBars.buttons.firstMatch.tap() // back

        // Albums: create one
        app.tabBars.buttons["Albums"].tap()
        let newAlbum = app.buttons["New Album"].firstMatch
        XCTAssertTrue(newAlbum.waitForExistence(timeout: 10))
        newAlbum.tap()
        let alert = app.alerts["New Album"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.textFields.firstMatch.typeText("Weekend Trip")
        alert.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Weekend Trip"].waitForExistence(timeout: 15), "New album should appear")
        capture("05-Albums")

        // Review: keep one, mark one for deletion, then delete it for real
        app.tabBars.buttons["Review"].tap()
        let monthRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'reviewed'")).firstMatch
        XCTAssertTrue(monthRow.waitForExistence(timeout: 10))
        capture("06-ReviewHome")
        monthRow.tap()

        let keep = app.buttons["Keep"]
        XCTAssertTrue(keep.waitForExistence(timeout: 10))
        pause(2)
        capture("07-Swipe")
        keep.tap()
        pause(1)
        app.buttons["Delete"].tap()
        pause(1)

        app.buttons["Finish"].tap()
        let confirmDelete = app.buttons["Delete 1 Item"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 10))
        capture("08-ReviewSummary")
        confirmDelete.tap()

        // iOS asks the person to confirm every deletion.
        let systemDelete = springboard.buttons["Delete"]
        XCTAssertTrue(systemDelete.waitForExistence(timeout: 10), "iOS should ask to confirm the deletion")
        capture("09-SystemDeleteConfirm", from: springboard)
        systemDelete.tap()
        XCTAssertTrue(app.tabBars.buttons["Review"].waitForExistence(timeout: 15), "Review should close after deleting")
        pause(2)
        capture("10-ReviewAfterDelete")

        // Settings
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        // LabeledContent merges label and value into one element, so match on either.
        let access = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'Full Access' OR value CONTAINS 'Full Access'")
        ).firstMatch
        XCTAssertTrue(access.waitForExistence(timeout: 10), "Settings should show full photo access")
        capture("11-Settings")
    }

    // MARK: - Helpers

    private func grantPhotoAccessIfAsked() {
        let allow = app.buttons["Allow Photo Access"]
        guard allow.waitForExistence(timeout: 8) else { return } // access already granted
        allow.tap()
        // The wording of the system prompt differs between iOS versions.
        let labels = ["Allow Full Access", "Allow Access to All Photos", "Allow"]
        for _ in 0..<2 {
            for label in labels {
                let button = springboard.buttons[label]
                if button.waitForExistence(timeout: 4) {
                    button.tap()
                    break
                }
            }
        }
    }

    private func capture(_ name: String, from target: XCUIApplication? = nil) {
        let attachment = XCTAttachment(screenshot: (target ?? app).screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "pause")], timeout: seconds)
    }
}
