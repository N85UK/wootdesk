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
    public var availabilityUpdateOutcome: Outcome<Void>
    /// Overrides the conversation returned after a triage change. When unset,
    /// the stub applies the requested change to its seeded conversation so that
    /// callers exercise a real confirmed-state transition.
    public var triageOutcome: Outcome<Conversation>?
    public var conversationLabelsOutcome: Outcome<[String]>?
    public var assignmentOptionsOutcome: Outcome<ConversationAssignmentOptions>
    public var accountLabelsOutcome: Outcome<[AccountLabel]>

    public init(
        profileOutcome: Outcome<ProfileResult> = .success(
            ProfileResult(name: "Sample Agent", accounts: [PreviewData.singleAccount])
        ),
        conversationsOutcome: Outcome<[Conversation]> = .success(PreviewData.conversations),
        messagesOutcome: Outcome<ConversationMessagePage> = .success(
            ConversationMessagePage(messages: PreviewData.messages, hasOlderMessages: false)
        ),
        createdMessageOutcome: Outcome<ConversationMessage>? = nil,
        availabilityUpdateOutcome: Outcome<Void> = .success(()),
        triageOutcome: Outcome<Conversation>? = nil,
        conversationLabelsOutcome: Outcome<[String]>? = nil,
        assignmentOptionsOutcome: Outcome<ConversationAssignmentOptions> = .success(
            PreviewData.assignmentOptions
        ),
        accountLabelsOutcome: Outcome<[AccountLabel]> = .success(PreviewData.accountLabels)
    ) {
        self.profileOutcome = profileOutcome
        self.conversationsOutcome = conversationsOutcome
        self.messagesOutcome = messagesOutcome
        self.createdMessageOutcome = createdMessageOutcome
        self.availabilityUpdateOutcome = availabilityUpdateOutcome
        self.triageOutcome = triageOutcome
        self.conversationLabelsOutcome = conversationLabelsOutcome
        self.assignmentOptionsOutcome = assignmentOptionsOutcome
        self.accountLabelsOutcome = accountLabelsOutcome
    }

    public func updateAvailability(
        baseURL: URL,
        token: String,
        accountID: Int,
        availability: AgentAvailability
    ) async throws {
        try await resolve(availabilityUpdateOutcome)
    }

    /// An invented Chatwoot user identifier for the stubbed agent, so
    /// enrolment carries an agent identity in previews and UI tests without
    /// contacting a server.
    public var stubAgentID: Int? = 1

    public func fetchProfile(
        baseURL: URL,
        token: String
    ) async throws -> (profileName: String, agentID: Int?, accounts: [ChatwootAccount]) {
        let result = try await resolve(profileOutcome)
        return (profileName: result.name, agentID: stubAgentID, accounts: result.accounts)
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

    // MARK: - Conversation Triage

    public func fetchConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> Conversation {
        if let triageOutcome {
            return try await resolve(triageOutcome)
        }
        return try await seededConversation(id: conversationID)
    }

    public func updateConversationStatus(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        status: ConversationStatus,
        snoozedUntil: Date?
    ) async throws -> Conversation {
        if status == .snoozed, snoozedUntil.map({ $0.timeIntervalSinceNow <= 0 }) ?? true {
            throw APIError.invalidSnoozeTime
        }
        if let triageOutcome {
            return try await resolve(triageOutcome)
        }
        return try await seededConversation(id: conversationID)
            .applying(status: status, snoozedUntil: .some(status == .snoozed ? snoozedUntil : nil))
    }

    public func updateConversationPriority(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        priority: ConversationPriority?
    ) async throws -> Conversation {
        if let triageOutcome {
            return try await resolve(triageOutcome)
        }
        return try await seededConversation(id: conversationID).applying(priority: .some(priority))
    }

    public func assignConversation(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        target: ConversationAssignmentTarget
    ) async throws -> Conversation {
        if let triageOutcome {
            return try await resolve(triageOutcome)
        }

        let options = try await resolve(assignmentOptionsOutcome)
        let conversation = try await seededConversation(id: conversationID)

        switch target {
        case .agent(let id):
            guard let agent = options.agents.first(where: { $0.id == id }) else {
                throw APIError.notFound
            }
            return conversation.applying(
                assignee: .some(ConversationAssignee(id: agent.id, name: agent.name))
            )
        case .team(let id):
            guard let team = options.teams.first(where: { $0.id == id }) else {
                throw APIError.notFound
            }
            return conversation.applying(team: .some(team))
        case .unassignAgent:
            return conversation.applying(assignee: .some(nil))
        case .unassignTeam:
            return conversation.applying(team: .some(nil))
        }
    }

    public func fetchConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int
    ) async throws -> [String] {
        if let conversationLabelsOutcome {
            return try await resolve(conversationLabelsOutcome)
        }
        return try await seededConversation(id: conversationID).labels
    }

    public func updateConversationLabels(
        baseURL: URL,
        token: String,
        accountID: Int,
        conversationID: Int,
        labels: [String]
    ) async throws -> [String] {
        if let conversationLabelsOutcome, case .failure = conversationLabelsOutcome {
            return try await resolve(conversationLabelsOutcome)
        }
        return labels
    }

    public func fetchAssignmentOptions(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> ConversationAssignmentOptions {
        try await resolve(assignmentOptionsOutcome)
    }

    public func fetchAccountLabels(
        baseURL: URL,
        token: String,
        accountID: Int
    ) async throws -> [AccountLabel] {
        try await resolve(accountLabelsOutcome)
    }

    /// Finds the seeded conversation a triage call refers to.
    ///
    /// An unknown identifier is reported as not found rather than substituted
    /// with another conversation.
    private func seededConversation(id: Int) async throws -> Conversation {
        let seeded = try await resolve(conversationsOutcome)
        guard let conversation = seeded.first(where: { $0.id == id }) else {
            throw APIError.notFound
        }
        return conversation
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
