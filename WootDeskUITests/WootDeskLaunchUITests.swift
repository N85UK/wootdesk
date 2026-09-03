import XCTest

/// Launch tests for the first-run experience.
///
/// The app is launched with `--uitesting`, which selects an in-memory environment.
/// No Keychain item, saved profile, or network request is involved.
final class WootDeskLaunchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchForFirstRun() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        return app
    }

    @MainActor
    private func launchWithInventedConversations() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-conversations"]
        app.launch()
        return app
    }

    /// N85-13 AC5 and N85-14 AC2.
    ///
    /// Unit tests already cover the layout *decision* at accessibility sizes:
    /// that the status filter becomes a menu and that row metadata stacks. They
    /// cannot show that the result is actually readable, because they never
    /// render anything. This launches the real interface at the largest
    /// accessibility text size and checks that nothing runs off the side.
    ///
    /// iOS only. macOS has no equivalent system control for text size, so the
    /// same assertion there would pass without testing anything.
    @MainActor
    func testConversationListStaysOperableAtAccessibilityTextSize() throws {
        #if os(macOS)
        throw XCTSkip("Accessibility text sizes are an iOS setting; this runs on iPhone and iPad.")
        #else
        let app = XCUIApplication()
        app.launchArguments = [
            "--uitesting-conversations",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        // Matched on a contained string, not equality: at accessibility sizes the
        // control becomes a menu button whose label composes the value with the
        // accessibility label, reading "Status Filter, Filter conversations by
        // status". An exact match silently finds nothing.
        let filter = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Filter conversations by status")
        ).firstMatch
        XCTAssertTrue(
            filter.waitForExistence(timeout: 20),
            "The status filter must remain present at the largest accessibility text size."
        )
        XCTAssertTrue(filter.isHittable, "The status filter must remain operable, not merely present.")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let bounds = window.frame

        // A control pushed off the right edge is the failure this guards against:
        // it reads as missing rather than as broken, so nobody reports it.
        var clipped: [String] = []
        for kind in [XCUIElement.ElementType.button, .staticText] {
            let matches = app.descendants(matching: kind).allElementsBoundByIndex
            for element in matches.prefix(40) where element.exists && element.frame.width > 0 {
                let frame = element.frame
                if frame.maxX > bounds.maxX + 1 || frame.minX < bounds.minX - 1 {
                    let label = element.label.isEmpty ? element.identifier : element.label
                    clipped.append("\(label.prefix(40)) at x \(Int(frame.minX))...\(Int(frame.maxX))")
                }
            }
        }
        XCTAssertTrue(
            clipped.isEmpty,
            "Content extends beyond the window at the largest accessibility text size: \(clipped.joined(separator: "; "))"
        )
        #endif
    }

    @MainActor
    func testFirstRunLaunchReachesSetupScreen() throws {
        let app = launchForFirstRun()

        let welcome = app.staticTexts["Welcome to WootDesk"]
        XCTAssertTrue(
            welcome.waitForExistence(timeout: 15),
            "First run should present the welcome screen when no server profile is saved."
        )

        let addServerButton = app.buttons["Add Chatwoot Server"]
        XCTAssertTrue(
            addServerButton.waitForExistence(timeout: 5),
            "First run should offer a control for adding a Chatwoot server."
        )
        XCTAssertTrue(addServerButton.isHittable)
    }

    @MainActor
    func testAddServerOpensConnectionSetup() throws {
        let app = launchForFirstRun()

        let addServerButton = app.buttons["Add Chatwoot Server"]
        XCTAssertTrue(addServerButton.waitForExistence(timeout: 15))
        #if os(macOS)
        addServerButton.click()
        #else
        XCTAssertTrue(addServerButton.isHittable)
        addServerButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        #endif

        let heading = app.staticTexts["Connect to Chatwoot"]
        XCTAssertTrue(
            heading.waitForExistence(timeout: 5),
            "Adding a server should present the connection setup form."
        )

        let serverField = app.textFields["Chatwoot Server URL"]
        XCTAssertTrue(serverField.exists, "The setup form should expose a server address field.")

        let tokenField = app.secureTextFields["Personal Access Token"]
        XCTAssertTrue(tokenField.exists, "The token must be entered in a secure field.")
    }

    /// Records cold-launch time against the invented first-run state.
    ///
    /// The launch reaches the setup screen with no saved profile, no Keychain
    /// access and no network call, so the measurement covers WootDesk's own
    /// start-up rather than a server round trip.
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting"]
            app.launch()
            app.terminate()
        }
    }

    @MainActor
    func testConversationHistoryAndReplyWithoutNetwork() throws {
        let app = launchWithInventedConversations()
        // The row is a navigation link on iPhone and a selectable split-view row
        // on Mac and iPad, so it is matched by identifier rather than by element
        // type.
        let conversationRow = app.descendants(matching: .any)
            .matching(identifier: "conversation-row-1041")
            .firstMatch
        XCTAssertTrue(
            conversationRow.waitForExistence(timeout: 15),
            "The invented conversation should load through the in-memory API stub."
        )

        #if os(macOS)
        conversationRow.click()
        #else
        conversationRow.tap()
        #endif

        let existingMessage = app.descendants(matching: .any)["message-8001"]
        XCTAssertTrue(
            existingMessage.waitForExistence(timeout: 5),
            "Selecting a conversation should load its message history."
        )

        let attachmentButton = app.buttons["Open sample-export.png"]
        XCTAssertTrue(
            attachmentButton.waitForExistence(timeout: 5),
            "A received attachment must remain an independently accessible control."
        )

        let composer = app.descendants(matching: .any)["conversation-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        #if os(macOS)
        composer.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)
        ).click()
        #else
        composer.tap()
        #endif
        composer.typeText("An invented UI test reply")

        let sendButton = app.buttons["send-message"]
        XCTAssertTrue(sendButton.isEnabled)
        #if os(macOS)
        sendButton.click()
        #else
        sendButton.tap()
        #endif

        let createdMessage = app.descendants(matching: .any)["message-9999"]
        XCTAssertTrue(
            createdMessage.waitForExistence(timeout: 5),
            "The reply should be appended only after the stub returns a created message."
        )
    }
}
