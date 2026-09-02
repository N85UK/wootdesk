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
    ) async throws -> (profileName: String, agentID: Int?, accounts: [ChatwootAccount])

    /// Updates the authenticated agent's availability for one account.
    func updateAvailability(
        baseURL: URL,
        token: String,
        accountID: Int,
        availability: AgentAvailability
    ) async throws

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

    /// Fetches one conversation, used to confirm the server state that follows a
    /// triage change rather than assuming the requested change was applied.
    func fetchConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> Conversation

    /// Applies a conversation status, supplying the return time when snoozing.
    ///
    /// - Returns: The conversation as the server reports it after the change.
    func updateConversationStatus(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        status: ConversationStatus,
        snoozedUntil: Date?
    ) async throws -> Conversation

    /// Applies a conversation priority.
    ///
    /// - Returns: The conversation as the server reports it after the change.
    func updateConversationPriority(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        priority: ConversationPriority?
    ) async throws -> Conversation

    /// Assigns the conversation to an agent or team, or clears an assignment.
    ///
    /// - Returns: The conversation as the server reports it after the change.
    func assignConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        target: ConversationAssignmentTarget
    ) async throws -> Conversation

    /// Reads the label titles the server currently holds for one conversation.
    func fetchConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> [String]

    /// Replaces the conversation label set with the supplied complete list.
    ///
    /// Chatwoot overwrites rather than merges, so callers must send the entire
    /// intended set. Callers read the current set first so that labels added on
    /// the server since the conversation was displayed are preserved.
    ///
    /// - Returns: The label titles confirmed by the server.
    func updateConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        labels: [String]
    ) async throws -> [String]

    /// Reads the agents and teams the account offers for assignment.
    func fetchAssignmentOptions(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> ConversationAssignmentOptions

    /// Reads the label set defined for the account.
    func fetchAccountLabels(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> [AccountLabel]
}
