import XCTest

/// Walks the app the way a person would and saves a PNG at each stop.
///
/// Run via `scripts/screenshots.sh`, which boots one simulator per App Store
/// device size, points location at Magic Kingdom, and sets
/// `SCREENSHOT_DIR` so the PNGs land in `screenshots/<device>/`. When the
/// env var is absent the images are still attached to the xcresult bundle.
///
/// Launch arguments used:
///   -screenshots            hides the ad banner (see BottomAdBanner)
///   -userDisplayName Robby  pre-seeds the onboarding name so the welcome
///                           sheet never appears (UserDefaults argument domain)
///   -qb.settings.defaultTab 0   always start on the Parks tab
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outputDir: URL?

    private let magicKingdomParkId = 6
    private let launchTimeout: TimeInterval = 60
    private let dataTimeout: TimeInterval = 120

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += [
            "-screenshots",
            "-userDisplayName", "Robby",
            "-qb.settings.defaultTab", "0",
        ]
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            outputDir = url
        }
        app.launch()
    }

    func testStoreScreenshots() throws {
        // 1. Parks list. Wait for live data, not just layout: the Magic
        //    Kingdom card's accessibility label gains "average wait" once the
        //    resort feed has loaded, and the hero card stops saying waits
        //    aren't in yet.
        let mkCard = app.descendants(matching: .any)["parkCard.\(magicKingdomParkId)"]
        XCTAssertTrue(mkCard.waitForExistence(timeout: launchTimeout), "Park list never loaded")
        let loadedCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'parkCard.\(magicKingdomParkId)' AND label CONTAINS 'average wait'")
        ).firstMatch
        XCTAssertTrue(loadedCard.waitForExistence(timeout: dataTimeout), "Wait times never arrived")
        dismissSystemAlerts()
        settle(4)
        snap(1, "parks")

        // 2. Magic Kingdom detail header.
        scrollIntoView(mkCard)
        mkCard.tap()
        let firstRow = anyAttractionRow()
        XCTAssertTrue(firstRow.waitForExistence(timeout: launchTimeout), "Park detail never loaded")
        dismissSystemAlerts()
        settle(4)
        snap(2, "magic-kingdom")

        // 4. Attraction detail, opened from the "Next departures" rows that
        //    sit near the top of the park detail on every device. (Tapping
        //    a row further down proved flaky: the list snaps back to the
        //    top when live data refreshes, so the tap lands on the header.)
        //    Those rows are always short-wait rides, so the capture shows a
        //    real split-flap number.
        let detailMarker = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == 'Add to My Day' OR label == 'In My Day' OR label == 'ABOUT'")
        ).firstMatch
        for _ in 0..<3 where !detailMarker.exists {
            let row = anyAttractionRow()
            guard row.waitForExistence(timeout: 5) else { break }
            // `row.tap()` never registers on iPad, so tap the row's frame
            // centre as a screen coordinate, which works on both devices.
            let f = row.frame
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: f.midX, dy: f.midY))
                .tap()
            _ = detailMarker.waitForExistence(timeout: 8)
        }
        if detailMarker.exists {
            settle(4)
            snap(4, "attraction-detail")
            goBack()
            _ = firstRow.waitForExistence(timeout: 10)
        } else {
            XCTFail("Attraction detail never opened; skipping that capture")
        }

        // 3. Attraction rows with the per-ride icons.
        app.swipeUp()
        app.swipeUp()
        settle(1)
        snap(3, "magic-kingdom-rides")

        // 5. Plan tab.
        tapTab("plan")
        settle(3)
        snap(5, "plan")

        // 6. Alerts tab.
        tapTab("alerts")
        settle(2)
        snap(6, "alerts")

        // 7. Map tab, last on purpose: once MapKit is on screen every
        //    element query risks "Timed out while evaluating UI query". Read
        //    the tab's frame now (still safe), then reach it by coordinate
        //    and take no further queries afterwards.
        let mapTab = app.buttons["tab.map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10), "Map tab missing")
        let target = mapTab.frame
        let window = app.frame
        let offset = CGVector(dx: target.midX / window.width, dy: target.midY / window.height)
        app.coordinate(withNormalizedOffset: offset).tap()
        settle(12)
        snap(7, "map")
    }

    // MARK: - Helpers

    private func snap(_ index: Int, _ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let filename = String(format: "%02d-%@.png", index, name)
        if let dir = outputDir {
            do {
                try shot.pngRepresentation.write(to: dir.appendingPathComponent(filename))
            } catch {
                XCTFail("Could not write \(filename): \(error)")
            }
        }
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle(_ seconds: TimeInterval) {
        // Idle wait so split-flap animations and network content finish.
        _ = app.wait(for: .runningForeground, timeout: seconds)
        Thread.sleep(forTimeInterval: seconds)
    }

    private func anyAttractionRow(hittable: Bool = false) -> XCUIElement {
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'attraction.'"))
        guard hittable else { return rows.firstMatch }
        // `hittable` is not a predicate key path, so filter in code. Skip the
        // first couple of rows, which may sit under the sticky header.
        let candidates = rows.allElementsBoundByIndex
        return candidates.dropFirst(2).first(where: { $0.isHittable })
            ?? candidates.first(where: { $0.isHittable })
            ?? rows.firstMatch
    }

    private func tapTab(_ name: String) {
        let tab = app.buttons["tab.\(name)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Tab \(name) missing")
        tab.tap()
    }

    private func goBack() {
        // Both custom back controls ("‹ PARKS", "‹ MAGIC KINGDOM PARK") are
        // buttons whose label starts with the chevron; fall back to an edge
        // swipe if neither is hittable.
        let back = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '‹'")).firstMatch
        if back.waitForExistence(timeout: 3) && back.isHittable {
            back.tap()
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        settle(1)
    }

    private func scrollIntoView(_ element: XCUIElement) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
    }

    /// Location and notification prompts are SpringBoard alerts, not part of
    /// the app hierarchy. Accept them so the "You're at" chip and alert
    /// features render in the captures.
    private func dismissSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 2) else { return }
            for label in ["Allow While Using App", "Allow", "OK"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    break
                }
            }
        }
    }
}
