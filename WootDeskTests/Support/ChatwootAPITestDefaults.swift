import Foundation
@testable import WootDesk

/// Signals that a test double was asked for an operation it does not stub.
///
/// Tests that exercise triage supply their own implementation. This error makes
/// an unstubbed call an obvious test-setup failure rather than something that
/// could be mistaken for a real server condition.
struct UnstubbedChatwootOperation: Error, CustomStringConvertible {
    let name: String

    var description: String {
        "The test double does not stub \(name)."
    }
}

/// Default triage implementations for test doubles focused on other features.
///
/// These exist only in the test target. The production module still requires
/// every conformer, including `ChatwootAPIClient` and `StubChatwootAPI`, to
/// implement each operation.
extension ChatwootAPIProtocol {
    func fetchConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> Conversation {
        throw UnstubbedChatwootOperation(name: "fetchConversation")
    }

    func updateConversationStatus(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        status: ConversationStatus,
        snoozedUntil: Date?
    ) async throws -> Conversation {
        throw UnstubbedChatwootOperation(name: "updateConversationStatus")
    }

    func updateConversationPriority(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        priority: ConversationPriority?
    ) async throws -> Conversation {
        throw UnstubbedChatwootOperation(name: "updateConversationPriority")
    }

    func assignConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        target: ConversationAssignmentTarget
    ) async throws -> Conversation {
        throw UnstubbedChatwootOperation(name: "assignConversation")
    }

    func fetchConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> [String] {
        throw UnstubbedChatwootOperation(name: "fetchConversationLabels")
    }

    func updateConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        labels: [String]
    ) async throws -> [String] {
        throw UnstubbedChatwootOperation(name: "updateConversationLabels")
    }

    func fetchAssignmentOptions(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> ConversationAssignmentOptions {
        throw UnstubbedChatwootOperation(name: "fetchAssignmentOptions")
    }

    func fetchAccountLabels(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> [AccountLabel] {
        throw UnstubbedChatwootOperation(name: "fetchAccountLabels")
    }
}
