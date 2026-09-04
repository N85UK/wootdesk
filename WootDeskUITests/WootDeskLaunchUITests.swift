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

    /// N85-14 AC1: every interactive control announces a meaningful name.
    ///
    /// A sweep rather than a spot check. Naming one control proves that control
    /// was labelled; AC1 asks about all of them, across the conversation list,
    /// the conversation detail, the composer and settings. An unlabelled button
    /// is announced by VoiceOver as "button", which says nothing about what it
    /// does.
    ///
    /// Every offender on every surface is reported at once rather than stopping
    /// at the first, so fixing them is one pass rather than run, fix, run.
    @MainActor
    func testEveryInteractiveControlAnnouncesAName() throws {
        let app = launchWithInventedConversations()

        let conversationRow = app.descendants(matching: .any)
            .matching(identifier: "conversation-row-1041")
            .firstMatch
        XCTAssertTrue(conversationRow.waitForExistence(timeout: 20))

        var findings: [String] = []
        var totalChecked = 0

        func sweep(_ surface: String) {
            var checked = 0
            for kind in [XCUIElement.ElementType.button, .textField, .secureTextField, .searchField] {
                for element in app.descendants(matching: kind).allElementsBoundByIndex {
                    guard element.exists, element.isHittable else { continue }
                    checked += 1
                    if element.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let identifier = element.identifier.isEmpty ? "no identifier" : element.identifier
                        findings.append("\(surface): \(kind.rawValue) with \(identifier)")
                    }
                }
            }
            totalChecked += checked
            print("LABEL_SWEEP \(surface): \(checked) controls")
        }

        sweep("conversation list")

        #if os(macOS)
        conversationRow.click()
        #else
        conversationRow.tap()
        #endif
        let composer = app.descendants(matching: .any)["conversation-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10), "The conversation detail should open.")
        sweep("conversation detail and composer")

        // Settings is the surface most likely to accumulate an unlabelled
        // icon-only control, so it is worth reaching rather than assuming.
        let settingsTab = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Settings"))
            .firstMatch
        if settingsTab.exists, settingsTab.isHittable {
            #if os(macOS)
            settingsTab.click()
            #else
            settingsTab.tap()
            #endif
            sweep("settings")
        } else {
            print("LABEL_SWEEP settings: not reachable from this layout, skipped")
        }

        // A clean result over an empty set is not a clean result.
        XCTAssertGreaterThan(
            totalChecked,
            10,
            "Only \(totalChecked) controls were reachable, too few for this sweep to mean anything."
        )
        XCTAssertTrue(
            findings.isEmpty,
            "Controls with no accessibility name, which VoiceOver announces only by role: \(findings.joined(separator: "; "))"
        )
    }

    /// Test plan, iPhone and iPad cases: "Rotate between portrait and landscape
    /// without losing the draft."
    ///
    /// A draft lost on rotation is the kind of defect nobody reports as a bug,
    /// because the agent assumes they did something wrong, and it costs them
    /// whatever they had typed.
    @MainActor
    func testDraftSurvivesRotation() throws {
        #if os(macOS)
        throw XCTSkip("Rotation is an iOS behaviour; this runs on iPhone and iPad.")
        #else
        let app = launchWithInventedConversations()

        let conversationRow = app.descendants(matching: .any)
            .matching(identifier: "conversation-row-1041")
            .firstMatch
        XCTAssertTrue(conversationRow.waitForExistence(timeout: 20))
        conversationRow.tap()

        let composer = app.descendants(matching: .any)["conversation-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()

        let draft = "An invented draft that must survive rotation"
        composer.typeText(draft)
        XCTAssertEqual(composer.value as? String, draft, "The composer should hold what was typed.")

        let portraitWidth = app.windows.firstMatch.frame.width

        XCUIDevice.shared.orientation = .landscapeLeft
        // Prove the rotation actually happened. Setting the orientation is a
        // request, not a guarantee: if the simulator ignores it the draft is
        // trivially still there and the test passes without having tested
        // anything.
        let rotated = app.windows.firstMatch.frame.width
        XCTAssertGreaterThan(
            rotated,
            portraitWidth,
            "The window did not get wider, so the device did not rotate and this test proved nothing."
        )

        // The composer is re-laid out, so find it again rather than reusing a
        // stale reference.
        let afterLandscape = app.descendants(matching: .any)["conversation-composer"]
        XCTAssertTrue(afterLandscape.waitForExistence(timeout: 10))
        XCTAssertEqual(
            afterLandscape.value as? String,
            draft,
            "Rotating to landscape must not discard the draft."
        )

        XCUIDevice.shared.orientation = .portrait
        let afterPortrait = app.descendants(matching: .any)["conversation-composer"]
        XCTAssertTrue(afterPortrait.waitForExistence(timeout: 10))
        XCTAssertEqual(
            afterPortrait.value as? String,
            draft,
            "Rotating back to portrait must not discard the draft."
        )

        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        #endif
    }

    /// Test plan, shared case 8: a private note's presentation must be
    /// unmistakable, because sending an internal note as a public reply is the
    /// one mistake in this app that a customer sees.
    @MainActor
    func testPrivateNoteModeIsAnnouncedDistinctly() throws {
        let app = launchWithInventedConversations()

        let conversationRow = app.descendants(matching: .any)
            .matching(identifier: "conversation-row-1041")
            .firstMatch
        XCTAssertTrue(conversationRow.waitForExistence(timeout: 20))
        #if os(macOS)
        conversationRow.click()
        #else
        conversationRow.tap()
        #endif

        let composer = app.descendants(matching: .any)["conversation-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertEqual(
            composer.label,
            "Reply text",
            "A public reply composer should announce itself as a reply."
        )

        let modeControl = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Choose public reply or private note"))
            .firstMatch
        XCTAssertTrue(modeControl.waitForExistence(timeout: 5), "The composer mode control should be reachable.")
        #if os(macOS)
        modeControl.click()
        #else
        modeControl.tap()
        #endif

        // The label is what VoiceOver reads out, so it is the thing that has to
        // change, not only the colour of the box.
        let privateComposer = app.descendants(matching: .any)["conversation-composer"]
        XCTAssertTrue(privateComposer.waitForExistence(timeout: 5))
        XCTAssertEqual(
            privateComposer.label,
            "Private note text",
            "Switching to a private note must change what the composer announces."
        )
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

    /// N85-14 AC6 requires the performance check to *fail* when a documented
    /// threshold is exceeded. `measure` with no stored baseline only records a
    /// number, so the cold-launch measurement could never fail and the criterion
    /// was met for the list and timeline checks but not for launch.
    ///
    /// This asserts a ceiling in the same style as the list and timeline checks:
    /// a regression ceiling, not a target, sized to catch something structural
    /// rather than a busy machine.
    @MainActor
    func testLaunchReachesFirstScreenWithinCeiling() throws {
        let ceiling: TimeInterval = 12.0

        var measurements: [TimeInterval] = []
        for _ in 0..<3 {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting"]
            let started = Date()
            app.launch()
            let welcome = app.staticTexts["Welcome to WootDesk"]
            XCTAssertTrue(
                welcome.waitForExistence(timeout: 30),
                "The first-run screen should appear; without it there is nothing to time."
            )
            measurements.append(Date().timeIntervalSince(started))
            app.terminate()
        }

        // The median, so one slow run on a loaded machine does not decide it.
        let median = measurements.sorted()[measurements.count / 2]
        print("LAUNCH_MEASUREMENTS \(measurements.map { String(format: "%.2f", $0) }.joined(separator: " ")) median \(String(format: "%.2f", median))")

        XCTAssertLessThan(
            median,
            ceiling,
            "Cold launch to the first-run screen took \(String(format: "%.2f", median))s, over the \(ceiling)s ceiling."
        )
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
        // Fifteen seconds, matching the other waits in this file. Five was
        // enough when this test ran alone and not when the whole suite ran on
        // one simulator, which made it fail intermittently for timing reasons
        // rather than behavioural ones. The assertion is unchanged: the reply
        // must still appear only after the stub confirms it.
        XCTAssertTrue(
            createdMessage.waitForExistence(timeout: 15),
            "The reply should be appended only after the stub returns a created message."
        )
    }
}
