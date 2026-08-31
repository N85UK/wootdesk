import Foundation

/// Protocol defining the agent-facing Chatwoot Application API capabilities.
public protocol ChatwootAPIProtocol: Sendable {
    /// Validates access credentials and fetches profile metadata including available accounts.
    ///
    /// - Parameters:
    ///   - baseURL: The validated Chatwoot server base URL.
    ///   - token: The personal API access token.
    /// - Returns: A tuple containing the profile display name and associated accounts.
    func fetchProfile(
        baseURL: URL,
        token: String
    ) async throws -> (profileName: String, accounts: [ChatwootAccount])

    /// Fetches a page of conversations for a specific account.
    ///
    /// - Parameters:
    ///   - baseURL: The validated Chatwoot server base URL.
    ///   - token: The personal API access token.
    ///   - accountID: The Chatwoot account ID.
    ///   - status: Optional conversation status filter. Pass `nil` to request Chatwoot's documented `all` status.
    ///   - page: The 1-indexed page number.
    /// - Returns: An array of decoded domain `Conversation` items.
    func fetchConversations(
        baseURL: URL,
        token: String,
        accountID: Int,
        status: ConversationStatus?,
        page: Int
    ) async throws -> [Conversation]

    /// Fetches the newest message page, or an older page before a message ID.
    func fetchMessages(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        beforeMessageID: Int?
    ) async throws -> ConversationMessagePage

    /// Creates a public outgoing reply or a private note.
    func createMessage(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        content: String,
        isPrivate: Bool,
        attachments: [OutgoingMessageAttachment]
    ) async throws -> ConversationMessage
}
