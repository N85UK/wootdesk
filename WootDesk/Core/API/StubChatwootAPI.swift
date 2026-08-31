import Foundation

/// A deterministic `ChatwootAPIProtocol` implementation for SwiftUI previews and tests.
///
/// This type performs no networking. It exists so that previews and unit tests can
/// drive the genuine loading, empty, error, and loaded states of the real views
/// rather than displaying hand-drawn imitations of them.
///
/// It is deliberately never wired into `AppEnvironment.live()`.
public struct StubChatwootAPI: ChatwootAPIProtocol {

    /// The result a stubbed call produces.
    public enum Outcome<Value: Sendable>: Sendable {
        /// Return the supplied value immediately.
        case success(Value)
        /// Throw the supplied error.
        case failure(APIError)
        /// Never return, leaving the caller in its loading state until cancelled.
        case pending
    }

    public struct ProfileResult: Sendable {
        public let name: String
        public let accounts: [ChatwootAccount]

        public init(name: String, accounts: [ChatwootAccount]) {
            self.name = name
            self.accounts = accounts
        }
    }

    public var profileOutcome: Outcome<ProfileResult>
    public var conversationsOutcome: Outcome<[Conversation]>
    public var messagesOutcome: Outcome<ConversationMessagePage>
    public var createdMessageOutcome: Outcome<ConversationMessage>?

    public init(
        profileOutcome: Outcome<ProfileResult> = .success(
            ProfileResult(name: "Sample Agent", accounts: [PreviewData.singleAccount])
        ),
        conversationsOutcome: Outcome<[Conversation]> = .success(PreviewData.conversations),
        messagesOutcome: Outcome<ConversationMessagePage> = .success(
            ConversationMessagePage(messages: PreviewData.messages, hasOlderMessages: false)
        ),
        createdMessageOutcome: Outcome<ConversationMessage>? = nil
    ) {
        self.profileOutcome = profileOutcome
        self.conversationsOutcome = conversationsOutcome
        self.messagesOutcome = messagesOutcome
        self.createdMessageOutcome = createdMessageOutcome
    }

    public func fetchProfile(
        baseURL: URL,
        token: String
    ) async throws -> (profileName: String, accounts: [ChatwootAccount]) {
        let result = try await resolve(profileOutcome)
        return (profileName: result.name, accounts: result.accounts)
    }

    public func fetchConversations(
        baseURL: URL,
        token: String,
        accountID: Int,
        status: ConversationStatus?,
        page: Int
    ) async throws -> [Conversation] {
        let all = try await resolve(conversationsOutcome)
        // `nil` mirrors the production client's explicit `status=all` request.
        let filtered = status.map { wanted in all.filter { $0.status == wanted } } ?? all
        // Only the first page carries stub data; later pages are empty so paging terminates.
        return page <= 1 ? filtered : []
    }

    public func fetchMessages(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        beforeMessageID: Int?
    ) async throws -> ConversationMessagePage {
        guard beforeMessageID == nil else {
            return ConversationMessagePage(messages: [], hasOlderMessages: false)
        }
        return try await resolve(messagesOutcome)
    }

    public func createMessage(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        content: String,
        isPrivate: Bool,
        attachments: [OutgoingMessageAttachment]
    ) async throws -> ConversationMessage {
        if let createdMessageOutcome {
            return try await resolve(createdMessageOutcome)
        }

        return ConversationMessage(
            id: 9_999,
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: .outgoing,
            isPrivate: isPrivate,
            createdAt: Date(timeIntervalSince1970: 1_735_737_000),
            senderName: "Sample Agent",
            senderType: "User",
            deliveryStatus: "sent",
            contentType: "text",
            attachments: attachments.enumerated().map { index, attachment in
                ConversationAttachment(
                    id: "stub-attachment-\(index)",
                    fileType: ConversationAttachmentType(
                        chatwootValue: attachment.mimeType.hasPrefix("image/") ? "image" : "file"
                    ),
                    fileSize: attachment.data.count,
                    fileExtension: URL(fileURLWithPath: attachment.fileName).pathExtension
                )
            }
        )
    }

    private func resolve<Value: Sendable>(_ outcome: Outcome<Value>) async throws -> Value {
        switch outcome {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .pending:
            // Suspend indefinitely so the caller remains in its loading state.
            try? await Task.sleep(for: .seconds(60 * 60))
            throw APIError.cancelled
        }
    }
}
