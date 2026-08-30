import Foundation

public enum ConversationStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case open
    case resolved
    case pending
    case snoozed

    public var displayName: String {
        switch self {
        case .open: return "Open"
        case .resolved: return "Resolved"
        case .pending: return "Pending"
        case .snoozed: return "Snoozed"
        }
    }
}

public enum ConversationPriority: String, Codable, Hashable, Sendable, CaseIterable {
    case urgent
    case high
    case medium
    case low

    public var displayName: String {
        switch self {
        case .urgent: return "Urgent"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

/// Domain model representing a Chatwoot conversation.
public struct Conversation: Identifiable, Codable, Hashable, Sendable {
    public let id: Int
    public let accountID: Int
    public let inboxID: Int
    public let status: ConversationStatus
    public let priority: ConversationPriority?
    public let contact: Contact?
    public let inboxName: String?
    public let lastActivityAt: Date
    public let unreadCount: Int
    public let lastMessagePreview: String?
    public let channel: String?
    public let createdAt: Date

    public init(
        id: Int,
        accountID: Int,
        inboxID: Int,
        status: ConversationStatus,
        priority: ConversationPriority? = nil,
        contact: Contact? = nil,
        inboxName: String? = nil,
        lastActivityAt: Date,
        unreadCount: Int = 0,
        lastMessagePreview: String? = nil,
        channel: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.accountID = accountID
        self.inboxID = inboxID
        self.status = status
        self.priority = priority
        self.contact = contact
        self.inboxName = inboxName
        self.lastActivityAt = lastActivityAt
        self.unreadCount = unreadCount
        self.lastMessagePreview = lastMessagePreview
        self.channel = channel
        self.createdAt = createdAt
    }
}
