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

    /// The statuses an agent can select directly. `snoozed` is excluded because
    /// it additionally requires a future return time.
    public static let directlySelectable: [ConversationStatus] = [.open, .pending, .resolved]
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
    /// The agent Chatwoot reports as responsible for this conversation.
    public let assignee: ConversationAssignee?
    /// The team Chatwoot reports as responsible for this conversation.
    public let team: AssignableTeam?
    /// Label titles confirmed by the server for this conversation.
    public let labels: [String]
    /// When a snoozed conversation returns to the open queue, where the server
    /// supplies the time.
    public let snoozedUntil: Date?

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
        createdAt: Date = Date(),
        assignee: ConversationAssignee? = nil,
        team: AssignableTeam? = nil,
        labels: [String] = [],
        snoozedUntil: Date? = nil
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
        self.assignee = assignee
        self.team = team
        self.labels = labels
        self.snoozedUntil = snoozedUntil
    }

    /// Decodes a stored conversation, tolerating payloads written before the
    /// triage fields existed. Their absence means "not known", never a
    /// fabricated assignment or label.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        accountID = try container.decode(Int.self, forKey: .accountID)
        inboxID = try container.decode(Int.self, forKey: .inboxID)
        status = try container.decode(ConversationStatus.self, forKey: .status)
        priority = try container.decodeIfPresent(ConversationPriority.self, forKey: .priority)
        contact = try container.decodeIfPresent(Contact.self, forKey: .contact)
        inboxName = try container.decodeIfPresent(String.self, forKey: .inboxName)
        lastActivityAt = try container.decode(Date.self, forKey: .lastActivityAt)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0
        lastMessagePreview = try container.decodeIfPresent(String.self, forKey: .lastMessagePreview)
        channel = try container.decodeIfPresent(String.self, forKey: .channel)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        assignee = try container.decodeIfPresent(ConversationAssignee.self, forKey: .assignee)
        team = try container.decodeIfPresent(AssignableTeam.self, forKey: .team)
        labels = try container.decodeIfPresent([String].self, forKey: .labels) ?? []
        snoozedUntil = try container.decodeIfPresent(Date.self, forKey: .snoozedUntil)
    }
}

public extension Conversation {
    /// Returns a copy with the supplied fields replaced.
    ///
    /// A parameter left unspecified keeps its current value. For the optional
    /// fields, pass `.some(nil)` to clear the value and `.some(value)` to set
    /// it, so that "leave unchanged" and "clear" stay distinguishable.
    func applying(
        status: ConversationStatus? = nil,
        priority: ConversationPriority?? = nil,
        assignee: ConversationAssignee?? = nil,
        team: AssignableTeam?? = nil,
        labels: [String]? = nil,
        snoozedUntil: Date?? = nil
    ) -> Conversation {
        Conversation(
            id: id,
            accountID: accountID,
            inboxID: inboxID,
            status: status ?? self.status,
            priority: priority ?? self.priority,
            contact: contact,
            inboxName: inboxName,
            lastActivityAt: lastActivityAt,
            unreadCount: unreadCount,
            lastMessagePreview: lastMessagePreview,
            channel: channel,
            createdAt: createdAt,
            assignee: assignee ?? self.assignee,
            team: team ?? self.team,
            labels: labels ?? self.labels,
            snoozedUntil: snoozedUntil ?? self.snoozedUntil
        )
    }
}
