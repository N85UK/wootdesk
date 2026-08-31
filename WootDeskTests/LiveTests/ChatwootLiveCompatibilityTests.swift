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
