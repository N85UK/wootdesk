import Foundation
import XCTest
@testable import WootDesk

/// Opt-in compatibility checks for an isolated Chatwoot server containing invented data.
///
/// These tests are skipped unless `WOOTDESK_LIVE_TESTS=1`. Mutating checks also
/// require both write gates documented in `docs/CHATWOOT_COMPATIBILITY.md`.
final class ChatwootLiveCompatibilityTests: XCTestCase {
    func testProfileConversationListAndHistoryCompatibility() async throws {
        let configuration = try liveConfiguration()
        let client = ChatwootAPIClient(isDebug: false)

        let profile = try await client.fetchProfile(
            baseURL: configuration.baseURL,
            token: configuration.token
        )
        XCTAssertTrue(
            profile.accounts.contains { $0.id == configuration.accountID },
            "The configured invented-data account must be available to the test agent."
        )

        _ = try await client.fetchConversations(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            status: nil,
            page: 1
        )

        let page = try await client.fetchMessages(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            conversationID: configuration.conversationID,
            beforeMessageID: nil
        )
        XCTAssertFalse(page.messages.isEmpty, "The compatibility conversation must contain invented messages.")
        XCTAssertEqual(
            Set(page.messages.map(\.id)).count,
            page.messages.count,
            "Chatwoot must return stable, unique message identifiers."
        )
    }

    func testPublicReplyPrivateNoteAndAttachmentCompatibility() async throws {
        let configuration = try liveConfiguration(requiresWrites: true)
        let client = ChatwootAPIClient(isDebug: false)

        let publicReply = try await client.createMessage(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            conversationID: configuration.conversationID,
            content: "WootDesk invented-data compatibility reply.",
            isPrivate: false,
            attachments: []
        )
        XCTAssertFalse(publicReply.isPrivate)
        XCTAssertEqual(publicReply.kind, .outgoing)

        let privateNote = try await client.createMessage(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            conversationID: configuration.conversationID,
            content: "WootDesk invented-data compatibility private note.",
            isPrivate: true,
            attachments: []
        )
        XCTAssertTrue(privateNote.isPrivate)

        let attachment = try OutgoingMessageAttachment(
            fileName: "wootdesk-invented-compatibility.txt",
            mimeType: "text/plain",
            data: Data("Invented WootDesk compatibility attachment.\n".utf8)
        )
        let attachmentReply = try await client.createMessage(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            conversationID: configuration.conversationID,
            content: "WootDesk invented-data attachment check.",
            isPrivate: false,
            attachments: [attachment]
        )
        XCTAssertEqual(attachmentReply.attachmentCount, 1)
        XCTAssertNotNil(
            attachmentReply.attachments.first?.dataURL,
            "The server must return a safe HTTPS data URL for the created attachment."
        )
    }

    /// Exercises availability and every triage behaviour against the approved
    /// invented-data server, restoring the conversation to the state it started
    /// in so the compatibility target is left unchanged.
    func testAvailabilityAndTriageCompatibility() async throws {
        let configuration = try liveConfiguration(requiresWrites: true)
        let client = ChatwootAPIClient(isDebug: false)

        // Availability round trip. The current value is written back, so the
        // agent's presence is confirmed as writable without changing it.
        let profile = try await client.fetchProfile(
            baseURL: configuration.baseURL,
            token: configuration.token
        )
        let account = try XCTUnwrap(
            profile.accounts.first { $0.id == configuration.accountID },
            "The configured invented-data account must be available to the test agent."
        )
        try await client.updateAvailability(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            availability: account.effectiveAvailability ?? .online
        )

        let original = try await client.fetchConversation(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            conversationID: configuration.conversationID
        )
        XCTAssertEqual(original.id, configuration.conversationID)

        // Assignment targets. An account may legitimately expose none, so an
        // empty set is recorded rather than treated as a failure.
        let options = try await client.fetchAssignmentOptions(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID
        )
        let accountLabels = try await client.fetchAccountLabels(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID
        )
        print("Compatibility: \(options.agents.count) agents, \(options.teams.count) teams, \(accountLabels.count) account labels.")

        do {
            // Status. The conversation is moved to a different status and then
            // restored.
            let target: ConversationStatus = original.status == .pending ? .open : .pending
            let afterStatus = try await client.updateConversationStatus(
                baseURL: configuration.baseURL,
                token: configuration.token,
                accountID: configuration.accountID,
                conversationID: configuration.conversationID,
                status: target,
                snoozedUntil: nil
            )
            XCTAssertEqual(
                afterStatus.status,
                target,
                "The server must confirm the requested status on a supported Chatwoot version."
            )

            // Priority, including clearing it.
            let afterPriority = try await client.updateConversationPriority(
                baseURL: configuration.baseURL,
                token: configuration.token,
                accountID: configuration.accountID,
                conversationID: configuration.conversationID,
                priority: .low
            )
            XCTAssertEqual(afterPriority.priority, .low)

            // Labels. The complete set is preserved across an add and a remove.
            let compatibilityLabel = "wootdesk-invented-compatibility"
            let labelsBefore = try await client.fetchConversationLabels(
                baseURL: configuration.baseURL,
                token: configuration.token,
                accountID: configuration.accountID,
                conversationID: configuration.conversationID
            )
            let intended = ConversationTriageState.merged(
                latest: labelsBefore,
                title: compatibilityLabel,
                isAdding: true
            )
            let afterAdd = try await client.updateConversationLabels(
                baseURL: configuration.baseURL,
                token: configuration.token,
                accountID: configuration.accountID,
                conversationID: configuration.conversationID,
                labels: intended
            )
            XCTAssertTrue(
                afterAdd.contains(compatibilityLabel),
                "The confirmed label set must contain the label that was added."
            )
            for existing in labelsBefore {
                XCTAssertTrue(
                    afterAdd.contains(existing),
                    "Adding a label must not discard the label \(existing) the server already held."
                )
            }

            let afterRemove = try await client.updateConversationLabels(
                baseURL: configuration.baseURL,
                token: configuration.token,
                accountID: configuration.accountID,
                conversationID: configuration.conversationID,
                labels: ConversationTriageState.merged(
                    latest: afterAdd,
                    title: compatibilityLabel,
                    isAdding: false
                )
            )
            XCTAssertFalse(afterRemove.contains(compatibilityLabel))
        } catch {
            try await restore(original, configuration: configuration, client: client)
            throw error
        }

        try await restore(original, configuration: configuration, client: client)
    }

    /// Returns the compatibility conversation to the status and priority it held
    /// before the mutating checks ran.
    private func restore(
        _ original: Conversation,
        configuration: LiveConfiguration,
        client: ChatwootAPIClient
    ) async throws {
        _ = try await client.updateConversationStatus(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            conversationID: configuration.conversationID,
            status: original.status,
            snoozedUntil: original.status == .snoozed ? original.snoozedUntil : nil
        )
        _ = try await client.updateConversationPriority(
            baseURL: configuration.baseURL,
            token: configuration.token,
            accountID: configuration.accountID,
            conversationID: configuration.conversationID,
            priority: original.priority
        )
    }

    private func liveConfiguration(requiresWrites: Bool = false) throws -> LiveConfiguration {
        let environment = ProcessInfo.processInfo.environment
        guard environment["WOOTDESK_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Opt-in live Chatwoot compatibility tests are disabled.")
        }

        guard let rawBaseURL = environment["WOOTDESK_LIVE_BASE_URL"],
              let tokenFilePath = environment["WOOTDESK_LIVE_TOKEN_FILE"],
              let accountValue = environment["WOOTDESK_LIVE_ACCOUNT_ID"],
              let accountID = Int(accountValue),
              let conversationValue = environment["WOOTDESK_LIVE_CONVERSATION_ID"],
              let conversationID = Int(conversationValue) else {
            XCTFail("The opt-in live test configuration is incomplete.")
            throw LiveCompatibilityConfigurationError.incomplete
        }

        let token: String
        do {
            let tokenData = try Data(contentsOf: URL(fileURLWithPath: tokenFilePath))
            guard let decodedToken = String(data: tokenData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !decodedToken.isEmpty else {
                throw LiveCompatibilityConfigurationError.incomplete
            }
            token = decodedToken
        } catch {
            XCTFail("The dedicated live-test token file could not be read.")
            throw LiveCompatibilityConfigurationError.incomplete
        }

        if requiresWrites {
            guard environment["WOOTDESK_LIVE_ALLOW_WRITES"] == "1",
                  environment["WOOTDESK_LIVE_CONFIRM_INVENTED_DATA"] == "1" else {
                throw XCTSkip("Mutating compatibility checks require both explicit write gates.")
            }
        }

        return LiveConfiguration(
            baseURL: try APIRequest.normaliseBaseURL(rawBaseURL, isDebug: false),
            token: token,
            accountID: accountID,
            conversationID: conversationID
        )
    }
}

private struct LiveConfiguration {
    let baseURL: URL
    let token: String
    let accountID: Int
    let conversationID: Int
}

private enum LiveCompatibilityConfigurationError: Error {
    case incomplete
}
