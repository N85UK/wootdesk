import Foundation

/// Privacy-conscious scope flags determining what data may be shared with the AI Gateway.
public struct AIContextScope: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Default baseline: public messages only, with PII redacted.
    public static let publicMessagesOnly = AIContextScope(rawValue: 1 << 0)
    /// Explicitly include customer identifier/name (excluding email & phone unless permitted).
    public static let includeCustomerName = AIContextScope(rawValue: 1 << 1)
    /// Explicitly include internal agent notes (requires explicit opt-in).
    public static let includeInternalNotes = AIContextScope(rawValue: 1 << 2)
    /// Explicitly include customer contact details (email/phone).
    public static let includeContactDetails = AIContextScope(rawValue: 1 << 3)
    /// Explicitly include custom attribute metadata.
    public static let includeCustomAttributes = AIContextScope(rawValue: 1 << 4)

    /// Safe default configuration: messages only, zero internal notes or sensitive attributes.
    public static let safeDefault: AIContextScope = [.publicMessagesOnly]
}

/// A request to conduct in-depth research through the authenticated WootDesk AI Gateway.
public struct ResearchRequest: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let conversationID: Int
    public let researchBrief: String
    public let scope: AIContextScope
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        conversationID: Int,
        researchBrief: String,
        scope: AIContextScope = .safeDefault,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.conversationID = conversationID
        self.researchBrief = researchBrief
        self.scope = scope
        self.createdAt = createdAt
    }
}

/// Lifecycle status for background research jobs executed by the gateway.
public enum ResearchJobStatus: String, Codable, Hashable, Sendable {
    case queued
    case running
    case completed
    case failed
    case cancelled
}

/// A verified citation source returned from an AI research run.
public struct ResearchCitation: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let url: URL?
    public let snippet: String
    public let dataSource: String

    public init(
        id: String,
        title: String,
        url: URL? = nil,
        snippet: String,
        dataSource: String
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.dataSource = dataSource
    }
}

/// The synthesized result of an AI research task.
public struct ResearchResult: Codable, Hashable, Sendable {
    public let reportMarkdown: String
    public let citations: [ResearchCitation]
    public let completedAt: Date

    public init(
        reportMarkdown: String,
        citations: [ResearchCitation],
        completedAt: Date = Date()
    ) {
        self.reportMarkdown = reportMarkdown
        self.citations = citations
        self.completedAt = completedAt
    }
}

/// A research job tracked asynchronously with the AI Gateway.
public struct ResearchJob: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let request: ResearchRequest
    public let status: ResearchJobStatus
    public let result: ResearchResult?
    public let errorMessage: String?
    public let startedAt: Date
    public let updatedAt: Date

    public init(
        id: String,
        request: ResearchRequest,
        status: ResearchJobStatus,
        result: ResearchResult? = nil,
        errorMessage: String? = nil,
        startedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.request = request
        self.status = status
        self.result = result
        self.errorMessage = errorMessage
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}

/// Request for conversation summarization.
public struct AISummaryRequest: Sendable {
    public let conversationID: Int
    public let messages: [String]
    public let scope: AIContextScope

    public init(conversationID: Int, messages: [String], scope: AIContextScope = .safeDefault) {
        self.conversationID = conversationID
        self.messages = messages
        self.scope = scope
    }
}

/// Request for drafting a reply.
public struct AIDraftReplyRequest: Sendable {
    public let conversationID: Int
    public let customerQuery: String
    public let instructions: String?
    public let tone: String?

    public init(conversationID: Int, customerQuery: String, instructions: String? = nil, tone: String? = nil) {
        self.conversationID = conversationID
        self.customerQuery = customerQuery
        self.instructions = instructions
        self.tone = tone
    }
}
