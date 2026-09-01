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
